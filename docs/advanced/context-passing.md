Commonly, the datafetcher for a nested field requires properties from its parent object to load its data.

Take the following schema example.

```
type Query {
  shows: [Show]
}

type Show {
  # The showId may or may not be there, depending on the scenario.
  showId: ID
  title: String
  reviews: [Review]
}

type Review {
  starRating: Int
}
```

Let's assume our backend already has methods available to Shows and Reviews from a datastore. 
Note that for this example, the `getShows` method does *not* return reviews.
The `getReviewsForShow` method loads reviews for a show, given the show id.

```java
interface ShowsService {
  List<Show> getShows(); //Does not include reviews
  List<Review> getReviewsForShow(int showId);   
}
```

For this scenario, you likely want to have two datafetchers, one for shows and one for reviews.
There are different options for implementing the datafetcher, which each has pros and cons depending on the scenario.
We'll go over the different scenarios and options.

The easy case - Using getSource 
-----

In the example schema the `Show` type has a `showId`.
Having the showId available makes loading reviews in a separate datafetcher very easy.
The `DataFetcherEnvironment` has a `getSource()` method that returns the parent loaded for a field.

```java
@DgsData(parentType = "Query", field = "shows")
List<Show> shows() {
  return showsService.getShows();
}

@DgsData(parentType = "Show", field = "reviews")
List<Review> reviews(DgsDataFetchingEnvironment dfe) {
  Show show = dfe.getSource();
  return showsService.getReviewsForShow(show.getShowId());
} 
```

This example is the easiest and most common scenario, but only possible if the `showId` field is available on the `Show` type.

No showdId - Use an internal type
----

Sometimes you don't want to expose the `showId` field in the schema, or our types are not set up to carry this field for other reasons.
For example, for 1:1 and N:1 it's not that common to model the relationship as a key in the Java model.
Whatever the reason is, the scenario we look at here is that we don't have the `showId` available on `Show`.

If we remove `showId` from the schema and use codegen, the generated `Show` type will not have `showId` field either.
Not having the `showId` field makes loading reviews a bit more complicated, because now we can't get the `showId` from the `Show` type using `getSource()`.

The `getShowsForService(int showId)` method indicates that internally (probably in the datastore), a show does have an id.
In such a scenario, we likely have a different internal representation of `Show` than exposed in the API.
For the remainder of the example, we'll call this the `InternalShow` type which the `ShowsService` returns.

```java  
interface ShowsService {
  List<InternalShow> getShows(); //Does not include reviews
  List<Review> getReviewsForShow(int showId);   
}

class InternalShow {
  int showId;
  Sring title;
  
  // getters and setters
}
```

However, the `Show` type in the GraphQL schema does not have a `showId`.

```
type Show {
  title: String
  reviews: [Review]
}
```

The good news is that you can have fields set on your internal instances either not in the schema, or not queried.
The framework drops this extra data while creating a response.

We could create an extra `ShowWithId` wrapper class that either extends or composes the (generated) `Show` type, and adds a `showId` field.

```java
class ShowWithId {
  String showId;
  Show show;
  
  //Delegate all show fields
  String getTitle() {
    return show.getTitle();
  }
  
  static ShowWithId fromInternalShow(InternalShow internal) {
    //Create Show instance and store id.
  }
  ....
}
```

The `shows` datafetcher should return the wrapper type instead of just `Show`.

```java
@DgsData(parentType = "Query", field = "shows")
List<Show> shows() {
  return showsService.getShows().stream()
    .map(ShowWithId::fromInternalShow)
    .collect(Collectors.toList());
}
```

As said, the extra field doesn't affect the response to the client at all.

No showId - use local context
-----

Using wrapper types works well when the schema type and internal type are mostly similar.
An alternative way is to use "local context".
A datafetcher can return a `DataFetcherResult<T>`, which contains `data`, `errors` and `localContext`.
The `data` and `errors` fields are the data and errors you would normally return directly from your datafetcher.
The `localContext` field can hold any data you want to pass down to child datafetchers.
The `localContext` can be retrieved in the child datafetcher from the `DataFetchingEnvironment` and is passed down to the next level child datafetchers if not overwritten.

In the following example the `shows` datafetcher creates a `DataFetcherResult` that holds the list of `Show` instances (not the internal type).
The `localContext` is set to a map with each `show` as key, and the `showId` as value.


```java
@DgsData(parentType = "Query", field = "shows")
public DataFetcherResult<List<Show>> shows(@InputArgument("titleFilter") String titleFilter) {
    List<InternalShow> internalShows = getShows(titleFilter);

    List<Show> shows = internalShows.stream()
        .map(s -> Show.newBuilder().title(s.getTitle()).build())
        .collect(Collectors.toList());
        return DataFetcherResult.<List<Show>>newResult()
            .data(shows)
            .localContext(internalShows.stream()
            .collect(Collectors.toMap(s -> Show.newBuilder().title(s.getTitle()).build(), InternalShow::getId)))
            .build();

}

private List<InternalShow> getShows(String titleFilter) {
    if (titleFilter == null) {
        return showsService.shows();
    }

    return showsService.shows().stream().filter(s -> s.getTitle().contains(titleFilter)).collect(Collectors.toList());
}
```

The `reviews` datafetcher can now use a combination of the `getSource` and `getLocalContext` methods to get the `showId` for a show.

```java
@DgsData(parentType = "Show", field = "reviews")
public CompletableFuture<List<Review>> reviews(DgsDataFetchingEnvironment dfe) {
    
    Map<Show, Integer> shows = dfe.getLocalContext();
    
    Show show = dfe.getSource();
    return showsService.getReviewsForShow(shows.get(show));
}
```

A benefit of this approach is that in contrast with `getSource`, the `localContext` gets passed down to the next level of child datafechers as well.

Pre-loading
-----
Suppose our internal datastore allows us to load shows and reviews together efficiently, for example using a SQL join query. 
In that case, it can be more efficient to pre-load reviews in the `shows` datafetcher.
In the `shows` datafetcher we can check if the `reviews` field was included in the query, and only if it is, load the reviews.
Depending on the Java/Kotlin types we use, the `Show` type may or may not have a `reviews` field.
If we use DGS codegen it will, and we can just set the `reviews` field when creating the `Show` instances in the `shows` datafetcher.
If the type returned by the `shows` datafetcher does not have a `reviews` field, we can again use the `localContext` to pass on the review data to a `reviews` datafetcher.
Below is an example of pre-loading and using `localContext`.

```java
@DgsData(parentType = "Query", field = "shows")
public DataFetcherResult<List<Show>> shows(DataFetchingEnvironment dfe) {
    List<Show> shows = showsService.shows();
    if (dfe.getSelectionSet().contains("reviews")) {

        Map<Integer, List<Review>> reviewsForShows = reviewsService.reviewsForShows(shows.stream().map(Show::getId).collect(Collectors.toList()));
        
        return DataFetcherResult.<List<Show>>newResult()
            .data(shows)
            .localContext(reviewsForShows)
            .build();
    } else {
        return DataFetcherResult.<List<Show>>newResult().data(shows).build();
    }
}

@DgsData(parentType = "Show", field = "reviews")
public List<Review> reviews(DgsDataFetchingEnvironment dfe) {
    Show show = dfe.getSource();

    //Load the reviews from the pre-loaded localContext.
    Map<Integer, List<Review>> reviewsForShows = dfe.getLocalContext();
    return reviewsForShows.get(show.getId());
}
```
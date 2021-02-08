It is common that the datafetcher for a nested field requires properties from its parent object to load its data.

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

Lets assume our backend already has methods available to Shows and Reviews from a datastore. 
Note that for this example, the `getShows` method does *not* return reviews.
To load reviews, the `getReviewsForShow` method must be called.

```java
interface ShowsService {
  List<Show> getShows(); //Does not include reviews
  List<Review> getReviewsForShow(int showId);   
}
```

For this scenario you likely want to have two data fetchers, one for shows, and one for reviews.
There are different options how to implement the datafetcher, which each has pros and cons depending on the scenario.
We'll go over the different scenarios and options.

The easy case - Using getSource 
-----

In the example schema the `Show` types has a `showId`.
This makes loading reviews in a separate datafetcher very easy.
The `DataFetcherEnvironment` has a `getSource()` method that returns the parent loaded for a field.

```java
@DgsData(parentType = "Query", field = "shows")
List<Show> shows() {
  return showsService.getShows();
}

List<Review> reviews(DgsDataFetchingEnvironment dfe) {
  Show show = dfe.getSource();
  return showsService.getReviewsForShow(show.getShowId());
} 
```

This is the easiest, and most common scenario, but only possible if the `showId` field is available on the `Show` type.

No showId - use local context
-----

Sometimes you don't want to expose the `showId` field in the schema.
That makes loading reviews a bit more complicated, because now we can't get the `showId` from the `Show` type using `getSource()`.

Looking at our internal `getShowsForService(int showId)` method, our internal API was designed around a `Show` having an id.
Likely, we have an internal representation of a show that is different from what's exposed in the GraphQL API. 
For the remainder of the example we'll call this the `InternalShow` type which the `ShowsService` returns.


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

The first approach to pass a showId to the `reviews` datafetcher is to use local context.

```java
@DgsData(parentType = "Query", field = "shows")
DataFetcherResult shows() {
  List<InternalShow> internalShows = showsService.getShows();
  List<Show> shows = internalShows.stream()
    .map(Show.newBuilder().title(InternalShow::getTitle).build())
    .collect(Collectors.toList());
  
  
  return DataFetcherResult.newResult()
    .data()
    .localContext(preFetchedComments)
    .build();
}

```

No showdId - Use an internal type
----



The good news is that you can have fields set on your internal instances that are either not in the schema, or not queried. 
The framework just drops this extra data while creating a response.

We could create an extra `ShowWithId` class that either extends or composes the (generated) `Show` type, and adds a `showId` field.

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

In the `shows` datafetcher instances of this class is returned, instead of just `Show`.

```java
@DgsData(parentType = "Query", field = "shows")
List<Show> shows() {
  return showsService.getShows().stream()
    .map(ShowWithId::fromInternalShow)
    .collect(Collectors.toList());
}
```

In contrast to using local context, this approach still works when shows are loaded through a data loader.
As said, this doesn't affect the response to the client at all.



The DGS framework supports Mutations with the same constructs as data fetchers, using<!-- http://go/pv http://go/use --> the `@DgsData` annotation.
The following is a simple example of a mutation:

```graphql
type Mutation {
    addRating(title: String, stars: Int):Rating
}

type Rating {
    avgStars: Float
}
```

```java
@DgsComponent
public class RatingMutation {
    @DgsData(parentType = "Mutation", field = "addRating")
    public Rating addRating(DataFetchingEnvironment dataFetchingEnvironment) {
        int stars = dataFetchingEnvironment.getArgument("stars");

        if(stars < 1) {
            throw new IllegalArgumentException("Stars must be 1-5");
        }

        String title = dataFetchingEnvironment.getArgument("title");
        System.out.println("Rated " + title + " with " + stars + " stars") ;

        return new Rating(stars);
    }
}
```

Note that the code above retrieves the input data for the Mutation by calling the `DataFetchingEnvironment.getArgument` method, just as data fetchers do for their arguments.

## Input Types

In the example above the input was two standard scalar types.
You can also use complex types, and you should define these as `input` types in your schema.
An `input` type is almost the same as a `type` in GraphQL, but with [some extra rules](https://graphql.org/learn/schema/#input-types).

According to the GraphQL specification an input type should<!-- http://go/should --> always be passed<!-- http://go/pv --> to the data fetcher as a `Map`.
This means the `DataFetchingEnvironment.getArgument` for an input type is a `Map`, and not the Java/Kotlin representation that you might have.
The framework has a convenience mechanism around this, which will be discussed next.
Let's first look at an example that uses DataFetchingEnvironment directly.

```graphql
type Mutation {
    addRating(input: RatingInput):Rating
}

input RatingInput {
    title: String,
    stars: Int
}

type Rating {
    avgStars: Float
}
```

```java
@DgsComponent
public class RatingMutation {
    @DgsData(parentType = "Mutation", field = "addRating")
    public Rating addRating(DataFetchingEnvironment dataFetchingEnvironment) {

        Map<String,Object> input = dataFetchingEnvironment.getArgument("input");
        RatingInput ratingInput = new ObjectMapper().convertValue(input, RatingInput.class);

        System.out.println("Rated " + ratingInput.getTitle() + " with " + ratingInput.getStars() + " stars") ;

        return new Rating(ratingInput.getStars());
    }
}

class RatingInput {
    private String title;
    private int stars;

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public int getStars() {
        return stars;
    }

    public void setStars(int stars) {
        this.stars = stars;
    }
}
```

## Input arguments as data fetcher method parameters
The framework makes it easier to get input arguments.
You can specify arguments as method parameters of a data fetcher.

```java
@DgsComponent
public class RatingMutation {
    @DgsData(parentType = "Mutation", field = "addRating")
    public Rating addRating(@InputArgument("input") RatingInput ratingInput) {
        //No need for custom parsing anymore!
        System.out.println("Rated " + ratingInput.getTitle() + " with " + ratingInput.getStars() + " stars") ;

        return new Rating(ratingInput.getStars());
    }
}
```

The `@InputArgument` annotation is important to specify the name of the input argument, because arguments can be specified in any order.
If no annotation is present, the framework tries to use the parameter name, but this is only possible if the code is compiled with [specific compiler settings](https://docs.oracle.com/javase/tutorial/reflect/member/methodparameterreflection.html).
Input type parameters can be combined with a `DataFetchingEnvironment` parameter.

```java
@DgsComponent
public class RatingMutation {
    @DgsData(parentType = "Mutation", field = "addRating")
    public Rating addRating(@InputArgument("input") RatingInput ratingInput, DataFetchingEnvironment dfe) {
        //No need for custom parsing anymore!
        System.out.println("Rated " + ratingInput.getTitle() + " with " + ratingInput.getStars() + " stars") ;
        System.out.println("DataFetchingEnvironment: " + dfe.getArgument(ratingInput));

        return new Rating(ratingInput.getStars());
    }
}
```

## Kotlin data types

In Kotlin, you can use Data Classes to represent input types.
However, make sure its<!-- "its" is ambiguous here --> fields are either `var` or add a `@JsonProperty` to each constructor argument, and use `jacksonObjectMapper()` to create a Kotlin-compatible Jackson mapper.

```kotlin
data class RatingInput(var title: String, var stars: Int)
```



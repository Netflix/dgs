
You must register type resolvers whenever you use interface types or union types in your schema.
Interface types and union types are explained in the [GraphQL documentation](https://graphql.org/learn/schema/#interfaces).

As an example, the following schema defines a `Movie` interface type with two different concrete object type implementations.

```graphql
type Query {
    movies: [Movie]
}

interface Movie {
    title: String
}

type ScaryMovie implements Movie {
    title: String
    gory: Boolean
    scareFactor: Int
}

type ActionMovie implements Movie {
    title: String
    nrOfExplosions: Int
}
```

The following data fetcher is registered to return a list of movies.
The data fetcher returns a combination `Movie` types.

```java
@DgsComponent
public class MovieDataFetcher {
    @DgsData(parentType = "Query", field = "movies")
    public List<Movie> movies() {
        return Lists.newArrayList(
                new ActionMovie("Crouching Tiger", 0),
                new ActionMovie("Black hawk down", 10),
                new ScaryMovie("American Horror Story", true, 10),
                new ScaryMovie("Love Death + Robots", false, 4)
            );
    }
}
```

The GraphQL runtime needs to know that a Java instance of `ActionMovie` represents the `ActionMovie` GraphQL type.
This mapping is the responsibility of a `TypeResolver`.

<div style="padding: 15px; border: 1px solid transparent; border-color: transparent; margin-bottom: 20px; border-radius: 4px; color: #8a6d3b;; background-color: #fcf8e3; border-color: #faebcc;">
Tip:
    If your Java type names and GraphQL type names are the same, the DGS framework creates a `TypeResolver` automatically. 
    No code needs to be added!
</div>
    
    

## Registering a Type Resolver

If the name of your Java type and GraphQL type don't match, you need to provide a `TypeResolver`.
A type resolver helps the framework map from concrete Java types to the correct object type in the schema.

Use the `@DgsTypeResolver` annotation to register a type resolver.
The annotation has a `name` property; set this to the name of the interface type or union type in the [GraphQL] schema.
The resolver takes an object of the Java interface type, and returns a String which is the concrete object type of the instance as defined in the schema.
The following is a type resolver for the `Movie` interface type introduced above:

```java
@DgsTypeResolver(name = "Movie")
public String resolveMovie(Movie movie) {
    if(movie instanceof ScaryMovie) {
        return "ScaryMovie";
    } else if(movie instanceof ActionMovie) {
        return "ActionMovie";
    } else {
        throw new RuntimeException("Invalid type: " + movie.getClass().getName() + " found in MovieTypeResolver");
    }
}
```

You can add the `@DgsTypeResolver` annotation to any `@DgsComponent` class.
This means you can either keep the type resolver in the same class as the data fetcher responsible for returning the data for this type, or you can create a separate class for it.

--8<-- "docs/reference_links"


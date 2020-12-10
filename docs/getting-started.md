## Create a new Spring Boot application

The DGS framework is based on Spring Boot, so get started by create a new Spring Boot application.
The Spring Initializr is an easy way to do so.
You can use either Gradle or Maven, Java 8 or newer or use Kotlin.
We do recommend Gradle because we have a really cool [code generation plugin](generating-code-from-schema) for it!

The only Spring dependency needed is Spring Web.

![Spring initializr](images/initializr.png)

Open the project in an IDE (Intellij recommended).

## Adding the [DGS] Framework Dependency

Add the `com.netflix.graphql.dgs:graphql-dgs-spring-boot-starter` dependency to your Gradle or Maven configuration.

Gradle
```groovy
dependencies {
    api "com.netflix.graphql.dgs:graphql-dgs-spring-boot-starter:latest.release"
}
```

Maven
```xml
<dependency>
    <groupId>com.netflix.graphql.dgs</groupId>
    <artifactId>graphql-dgs-spring-boot-starter</artifactId>
    <!-- Make sure to set the latest framework version! -->
    <version>${dgs.framework.version}</version>
</dependency>
```

## Creating a Schema

The DGS framework is designed for schema first development.
The framework picks up any schema files in the `src/main/resources/schema` folder.
Create a schema file in: `src/main/resources/schema/schema.graphqls`.

```graphql
type Query {
    shows(titleFilter: String): [Show]    
}

type Show {
    title: String
    releaseYear: Int
}
```

This schema allows querying for a list of shows, optionally filtering by title.

## Implement a Data Fetcher

Data fetchers are responsible for returning data for a query.
Create two new classes `example.ShowsDataFetcher` and `Show` and add the following code.

Java
```java
@DgsComponent
public class ShowsDatafetcher {

    private final List<Show> shows = List.of(
            new Show("Stranger Things", 2016),
            new Show("Ozark", 2017),
            new Show("The Crown", 2016),
            new Show("Dead to Me", 2019),
            new Show("Orange is the New Black", 2013)
    );

    @DgsData(parentType = "Query", field = "shows")
    public List<Show> shows(@InputArgument("titleFilter") String titleFilter) {
        if(titleFilter == null) {
            return shows;
        }

        return shows.stream().filter(s -> s.getTitle().contains(titleFilter)).collect(Collectors.toList());
    }
}

public class Show {
    private final String title;
    private final Integer releaseYear   ;

    public Show(String title, Integer releaseYear) {
        this.title = title;
        this.releaseYear = releaseYear;
    }

    public String getTitle() {
        return title;
    }

    public Integer getReleaseYear() {
        return releaseYear;
    }
}
```

Kotlin
```kotlin
@DgsComponent
class ShowsDataFetcher {
    private val shows = listOf(
        Show("Stranger Things", 2016),
        Show("Ozark", 2017),
        Show("The Crown", 2016),
        Show("Dead to Me", 2019),
        Show("Orange is the New Black", 2013))

    @DgsData(parentType = "Query", field = "shows")
    fun shows(@InputArgument("titleFilter") titleFilter : String?): List<Show> {
        return if(titleFilter != null) {
            shows.filter { it.title.contains(titleFilter) }
        } else {
            shows
        }
    }

    data class Show(val title: String, val releaseYear: Int)
}
```

That's all the code needed, the application is ready to be tested!

## Test the app with GraphiQL

Start the application and open a browser to http://localhost:8080/graphiql.
GraphiQL is a query editor that comes out of the box with the DGS framework.
Write the following query and tests the result.

```graphql
{
    shows {
        title
        releaseYear
    }
}
```

Note that unlike with REST, you have to specifically list which fields you want to get returned from your query.
This is where a lot of the power from GraphQL comes from, but a surprise to many developers new to GraphQL.

The GraphiQL editor is really just a UI that uses the `/graphql` endpoint of your service.
You could now connect a UI to your backend as well, for example using [React and the Apollo Client](https://www.apollographql.com/docs/react/).

## Next steps

Now that you have a first GraphQL service running, we recommend improving this further by doing the following:

* Use the [Gradle CodeGen plugin](generating-code-from-schema) - this will generate the data types for you.
* Write [query tests](query-execution-testing) in JUnit
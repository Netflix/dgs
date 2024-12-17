## Introduction

The DGS framework makes it easy to create GraphQL services with Spring Boot.
The framework provides an easy-to-use annotation based programming model,
and all the advanced features needed to build and run GraphQL services at scale.

The DGS framework is primarily maintained by Netflix, surrounded by an active community.
At Netflix we build our GraphQL architecture on the DGS framework.

## Create a new Spring Boot application

The DGS framework is now based on Spring Boot 3

The easiest way to create a DGS project is to use the Spring Initializr. 
You'll need to following dependencies:

1. Netflix DGS
2. Spring Web or Spring Reactive Web (WebFlux)
3. (Optional) GraphQL DGS Code Generation

![Spring initializr](images/spring-initializr.png)


You can use either Gradle or Maven with Java 17 or Kotlin.
We do recommend Gradle because we have a really cool [code generation plugin](generating-code-from-schema.md) for it!

Open the project in an IDE (Intellij recommended).

## Requirements
The DGS framework requires Spring Boot 3 and JDK 17 for your project.
The last version compatible with Spring Boot 2 and JDK 8 was 5.x, which is no longer maintained.

## Adding the DGS Framework dependency with Spring for GraphQL

*If you used the Spring Initializr to generate your DGS project, these steps are not necessary, your project is ready to go!*

1. **Add the platform BOM** to your Gradle or Maven configuration.
   The `com.netflix.graphql.dgs:graphql-dgs-platform-dependencies` dependency is a [platform/BOM dependency](https://netflix.github.io/dgs/advanced/platform-bom/), which aligns the versions of the individual modules and transitive dependencies of the framework.

2. **Add the DGS starter**.
   The `com.netflix.graphql.dgs:dgs-starter` is a Spring Boot starter that includes everything you need to get started building a DGS that uses Spring GraphQL.

3. **Add the relevant Spring Boot starter for the web flavor you want to use**.
   This would one of `org.springframework.boot:spring-boot-starter-web` or `org.springframework.boot:spring-boot-starter-webflux` depending on the stack you are using.

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

With the new Spring-GraphQL integration, it is technically possible to mix and match the DGS/Spring-GraphQL programming models.
However, to maintain consistency in your codebase and to take full advantage of DGS features, we recommend sticking with the DGS programming model.
Not all DGS features are applicable to Spring-GraphQL data fetchers in the current integration and would therefore not work as expected.
Refer to our [Known Gaps and Limitations](./spring-graphql-integration.md#known-gaps-and-limitations) section for more details.

Create two new classes `example.ShowsDataFetcher` and `Show` and add the following code.

Note that we have a [Codegen plugin](generating-code-from-schema.md) that can do this automatically, but in this guide we'll manually write the classes.

=== "Java"
   ```java
   import java.util.List;
   import java.util.stream.Collectors;
   
   import com.netflix.graphql.dgs.DgsComponent;
   import com.netflix.graphql.dgs.DgsQuery;
   import com.netflix.graphql.dgs.InputArgument;
   
   @DgsComponent
   public class ShowsDataFetcher {
   
     private final List<Show> shows = List.of(
             new Show("Stranger Things", 2016),
             new Show("Ozark", 2017),
             new Show("The Crown", 2016),
             new Show("Dead to Me", 2019),
             new Show("Orange is the New Black", 2013)
     );
   
     @DgsQuery
     public List<Show> shows(@InputArgument String titleFilter) {
         if(titleFilter == null) {
             return shows;
         }
   
         return shows.stream().filter(s -> s.title().contains(titleFilter)).collect(Collectors.toList());
     }
   }
   
   record Show(String title, int releaseYear) {}
   ```

=== "Kotlin"
   ```kotlin
   import java.util.List;
   import java.util.stream.Collectors;
   
   import com.netflix.graphql.dgs.DgsComponent;
   import com.netflix.graphql.dgs.DgsQuery;
   import com.netflix.graphql.dgs.InputArgument;
   
   @DgsComponent
   class ShowsDataFetcher {
     private val shows = listOf(
         Show("Stranger Things", 2016),
         Show("Ozark", 2017),
         Show("The Crown", 2016),
         Show("Dead to Me", 2019),
         Show("Orange is the New Black", 2013))
   
     @DgsQuery
     fun shows(@InputArgument titleFilter : String?): List<Show> {
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

Start the application and open a browser to [http://localhost:8080/graphiql](http://localhost:8080/graphiql).
GraphiQL is a query editor that comes out of the box with the DGS framework.
Write the following query and tests the result.

```shell
gradle bootRun
```

```shell
mvn spring-boot:run
```

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

## Install the Intellij plugin

If you are an Intellij user, there is a plugin available for DGS.
The plugin supports navigation between schema files and code and many hints and quick fixes.
You can install the plugin from the Jetbrains plugin repository [here](https://plugins.jetbrains.com/plugin/17852-dgs).

![Plugin installation](./images/intellij-marketplace.png)

## Next steps

Now that you have a first GraphQL service running, we recommend improving this further by doing the following:

* [Use the DGS Platform BOM](advanced/platform-bom.md) to align DGS Framework dependencies.
* Learn more about [datafetchers](datafetching.md)
* Use the [Gradle CodeGen plugin](generating-code-from-schema.md) - this will generate the data types for you.
* Write [query tests](query-execution-testing.md) in JUnit
* Look at [example projects](examples.md)

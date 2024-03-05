## DGS Framework now using Spring GraphQL!
The DGS and Spring-GraphQL teams are super excited to introduce deep integration between the DGS framework and Spring-GraphQL. 
This will bring the community together, and we can continue building the best possible GraphQL framework for Spring Boot in the future.


With this integration, it is technically possible to mix and match the DGS/Spring-GraphQL programming models. 
However, to maintain consistency in your codebase and to take full advantage of DGS features, we recommend sticking with the DGS programming model. 
Additional features from spring-graphql will be available via existing spring-graphql extensions, such as [multipart-spring-graphql](https://github.com/nkonev/multipart-spring-graphql) and the [Subscription Callback mechanism](https://github.com/apollographql/federation-jvm/pull/354) in the JVM Federation library.

Continue reading to know more about how to use [Spring GraphQL] (https://docs.spring.io/spring-graphql/reference/index.html) with the DGS Framework.

## Background - Two competing frameworks
The DGS Framework provides Java developers with a programming model on top of Spring Boot to create GraphQL services. 
Netflix open-sourced the DGS framework in 2021, and has been the widely adopted GraphQL Java framework by many companies.

While we continued adoption and development on the DGS Framework, the team at Spring were also exploring GraphQL support for Spring Boot. 
This effort was already underway prior to open-sourcing the DGS framework, while the Spring GraphQL efforts were also yet to be announced. 
After open sourcing the framework, both teams convened to discuss the current state and future direction. 
At the time Spring GraphQL was not as feature rich in comparison to the DGS Framework and we both  decided to continue what we were doing. 
While both the frameworks started with different goals and approaches, over the past year, Spring-GraphQL has matured and reached feature parity with many aspects of the DGS framework. 
This resulted in two "competing" frameworks in the community that largely solved the same problem.

Today, new users must choose between one or the other, raising questions about which framework to adopt. 
It might also mean missing out on features available in one framework but not the other. This is not an ideal situation for the Java/GraphQL community.

For the maintainers of both frameworks, it would be much more efficient to collaborate on features and improvements instead of having to solve the same problem twice. 
Notably, bringing the communities together is a highly desirable goal!

### Why not just EOL one of the frameworks?
The DGS framework is widely used and plays a vital role in the architecture of many companies, including Netflix. 
Moving away from the framework in favor of Spring-GraphQL would be a costly migration without any real benefits.

Although Spring-GraphQL doesn't have the user base of DGS, it makes sense from a Spring Framework perspective to have an out-of-the-box GraphQL offering, just like Spring supports REST.

## The way forward
With this integration, you can pull in additional features from Spring GraphQL. 
We also eliminate the need for part of the DGS code that integrates the framework with Spring MVC/WebFlux, since there isn't much benefit to duplicating low level functionality.

For the near term, the DGS/Spring-Graphql integration will be available as an opt-in feature via a different spring-graphql flavor of the DGS starter. 
We plan to make this the default mode towards the latter part the year, after we see some level of successful adoption.

## Technical implementation
Both DGS and Spring-GraphQL are designed with modularity and extensibility in mind. This makes it feasible to integrate the two frameworks. The following diagrams show how the frameworks are integrated at a high level.

Today, the DGS framework looks as follows.
A user uses the DGS programming model, such as `@DgsComponent` and `@DgsQuery` to define data fetchers etc.
A GraphQL query comes in through either WebMVC or WebFlux, and is executed by the `DgsQueryExecutor`, which builds on the graphql-java library to execute the query.
The `DgsQueryExecutor` is also used directly when writing tests.
<img width="722" alt="image" src="https://github.com/Netflix/dgs-framework/assets/109484/6bb0763a-015f-4d0a-994c-51807ecebb47">

With the Spring-GraphQL integration, a user can write code with both the DGS programming model and/or the Spring-GraphQL programming model. 
A GraphQL query comes in through WebMVC/WebFlux/RSocket, which Spring-GraphQL now handles. 
The representation of the schema (a `GraphQLSchema` from graphql-java) is created by the DGS framework, and used by both the DGS and Spring-GraphQL components. 
Spring-GraphQL's `ExecutionGraphQLService` now handles the actual query execution, while the DGS `QueryExecutor` becomes a proxy on top of `ExecutionGraphQLService` so that existing test code continues to work.
![image](https://github.com/Netflix/dgs-framework/assets/109484/a0d8a5cc-96ca-4f30-bd0a-e3bb3616689e)

## Performance
At Netflix, we tested the DGS/Spring-GraphQL integration on some of our largest services. 
Surprisingly, we uncovered a few performance issues in Spring WebMVC/Spring GraphQL with this integration. 
The Spring team has quickly addressed these issues, and the performance is now even better compared to baseline performance of Netflix applications with just the regular DGS Framework.

## Notable Changes and Improvements
The good news is that the new integration has been mostly a drop-in replacement, not requiring any breaking code changes for the user. 
Besides the features and changes listed in this section, everything else should continue to work as expected.

### DGS Configuration with Spring GraphQL
There is some overlap between configuration properties for DGS and Spring-GraphQL. Where properties overlap, we use the DGS property for the best backward compatibility. The following list is the overlapping properties.

| *DGS property* | *Spring-GraphQL property* | *What to use* |
|----|----| ----- |
| `dgs.graphql.schema-locations` | `spring.graphql.schema.locations` |  Use `dgs.graphql.schema-locations` |
| N/A | `spring.graphql.schema.fileExtensions` | Not applicable, because `dgs.graphql.schema-locations` includes the path |
| `dgs.graphql.graphiql.enabled` | `spring.graphql.graphiql.enabled` | Use `dgs.graphql.graphiql.enabled` |
| `dgs.graphql.graphiql.path` | `spring.graphql.graphiql.path` | Use `dgs.graphql.graphiql.path` |
| `dgs.graphql.websocket.connection-init-timeout` | `spring.graphql.websocket.connection-init-timeout` | DGS property sets the Spring-GraphQL property | 


### File Uploads
Support for file uploads will no longer be available by default in the DGS framework. 
This is supported using an external dependency for spring-graphql via [multipart-spring-graphql](https://github.com/nkonev/multipart-spring-graphql).

### Schema Inspection
You can now inspect your schema using Spring GraphQL's [schema inspection] (https://docs.spring.io/spring-graphql/reference/request-execution.html#execution.graphqlsource.schema-mapping-inspection) feature for DGS data fetchers as well.
You can now inspect schema fields and validate existing DGS data fetcher/and or Spring GraphQL data fetcher registrations, to check if all schema fields are covered either by an explicitly registered DataFetcher, or a matching Java object property. 
The inspection also performs a reverse check looking for DataFetcher registrations against schema fields that don’t exist.

### Testing DGS Data Fetchers
For testing individual data fetchers without the web layer, you can continue using the existing testing framework provided via `DgsQueryExecutor` interface. 
We have provided a Spring GraphQL flavor of the `DgsQueryExecutor` that will continue to work as it does today.
Please refer to our testing docs for more details on writing [data fetcher tests](query-execution-testing.md).

For integration testing with the web layer, you can also use the MockMvc test set up that Spring provides.
It is worth noting that with the Spring GraphQL integration, your MockMVC test set up does need to be updated.
Since web request processing is now based on async dispatching mechanism, we now [require explicit handling for this](https://docs.spring.io/spring-framework/reference/testing/spring-mvc-test-framework/async-requests.html) in the test setup. 

As an alternative, you can also use the [recommended `HttpGraphQlTester` with MockMvc available in Spring GraphQL](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#features.testing.spring-boot-applications.spring-graphql-tests) to achieve the same.
This works just as well for testing your DGS with a mock web layer as shown in the example below:

```java
@SpringBootTest
@AutoConfigureMockMvc
@AutoConfigureHttpGraphQlTester
public class HttpGraphQlTesterTest {

    @Autowired
    private HttpGraphQlTester graphQlTester;
    
    @Test
    void testDgsDataFetcher() {
        graphQlTester.document("query Hello($name: String){ hello(name: $name) }").variable("name", "DGS").execute()
                .path("hello").entity(String.class).isEqualTo("hello, DGS!");
    }
}
```

## Known Gaps
At this time, we are lacking support for SSE based subscriptions and Persisted Queries that are available in the original DGS Framework. 
These are on the roadmap and will be made available in the near future depending on support in spring-graphql. 


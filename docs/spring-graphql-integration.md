## Spring GraphQL Integration 
The DGS Framework now integrates with Spring GraphQL internally.
Users can continue using the DGS framework as is without additional changes.
Please refer to out [Getting Started guide](./getting-started.md) for more details.
The integration with Spring GraphQL will allow DGS users to take advantage of any new features that Spring GraphQL has to offer without having to reimplement it in the framework.
While it is technically possible to mix and match the DGS/Spring-GraphQL programming models, we recommend sticking with the DGS programming model for now, if using the DGS Framework.
By the DGS programming model, we specifically refer to DGS concepts, such as the annotations for setting up data fetchers, data loaders etc.
This will allow users to maintain consistency in the codebase and take full advantage of DGS capabilities.

It is important to note that Spring GraphQL and the DGS framework offer many similar features that may differ in capabilities. 
For that reason, Spring GraphQL features work best for Spring GraphQL style resolvers and vice versa.
A nice benefit to integrating with Spring GraphQL, is that it paves a way for new features in Spring GraphQL to be used in the DGS Framework.
These will be available via existing spring-graphql extensions, such as the [Subscription Callback mechanism](https://github.com/apollographql/federation-jvm/pull/354) in the JVM Federation library.

Continue reading to know more about how to use [Spring GraphQL] (https://docs.spring.io/spring-graphql/reference/index.html) with the DGS Framework.

## Background - Two competing frameworks
The DGS Framework provides Java developers with a programming model on top of Spring Boot to create GraphQL services. 
Netflix open-sourced the DGS framework in 2021, and has been the widely adopted GraphQL Java framework by many companies.

While we continued adoption and development on the DGS Framework, the team at Spring were also exploring GraphQL support for Spring Boot. 
This effort was already underway prior to open-sourcing the DGS framework.
While both the frameworks started with different goals and approaches, over the past year, Spring-GraphQL has matured and reached feature parity with many aspects of the DGS framework. 
This resulted in two "competing" frameworks in the community that largely solved the same problem.

Today, new users must choose between one or the other, raising questions about which framework to adopt. 
It might also mean missing out on features available in one framework but not the other. This is not an ideal situation for the Java/GraphQL community.

For the maintainers of both frameworks, it would be much more efficient to collaborate on features and improvements instead of having to solve the same problem twice. 
Notably, bringing the communities together is a highly desirable goal.

### Why not just EOL one of the frameworks?
The DGS framework is widely used and plays a vital role in the architecture of many companies, including Netflix. 
Moving away from the framework in favor of Spring-GraphQL would be a costly migration without any real benefits.

From a Spring Framework perspective, it makes sense to have an out-of-the-box GraphQL offering, just like Spring supports REST.

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
There is some overlap between configuration properties for DGS and Spring-GraphQL.
Where properties overlap, we use the DGS property for the best backward compatibility. 
The following is the list of overlapping properties:

| *DGS property* | *Spring-GraphQL property* | *What to use* |
|----|----| ----- |
| `dgs.graphql.schema-locations` | `spring.graphql.schema.locations` |  Use `dgs.graphql.schema-locations` |
| N/A | `spring.graphql.schema.fileExtensions` | Not applicable, because `dgs.graphql.schema-locations` includes the path |
| `dgs.graphql.graphiql.enabled` | `spring.graphql.graphiql.enabled` | Use `dgs.graphql.graphiql.enabled` |
| `dgs.graphql.graphiql.path` | `spring.graphql.graphiql.path` | Use `dgs.graphql.graphiql.path` |
| `dgs.graphql.websocket.connection-init-timeout` | `spring.graphql.websocket.connection-init-timeout` | DGS property sets the Spring-GraphQL property | 

New properties for Spring GraphQl integration are:

| *DGS Property* | *Description*                                    |
|---|-----|
`dgs.graphql.spring.webmvc.asyncdispatch.enabled` | To enable async dispatching for GraphQL requests |

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

You can also use the [recommended `HttpGraphQlTester` with MockMvc available in Spring GraphQL](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#features.testing.spring-boot-applications.spring-graphql-tests) to achieve the same.
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

### Async Dispatch
By default, Spring GraphQL uses async dispatch for handling HTTP GraphQL Requests when using WebMVC. 
In this DGS Framework we have turned off this behavior by default to preserve existing functionality, since it requires existing code to be async aware.
This implies servlet filters, tests etc. need to be also async aware.
You can turn on async behavior by setting the `dgs.graphql.spring.webmvc.asyncdispatch.enabled` to true. 

It is worth noting that with the Spring GraphQL integration, your MockMVC test set up does need to be updated.
Since web request processing is now based on async dispatching mechanism, we now [require explicit handling for this](https://docs.spring.io/spring-framework/reference/testing/spring-mvc-test-framework/async-requests.html) in the test setup.

## Known Gaps and Limitations
At this time, we are lacking support for SSE based subscriptions which is available in the original DGS Framework. 
This is on the roadmap and will be made available in the near future depending on support in spring-graphql. 

In the current state of integration, not all DGS features will work seamlessly for Spring GraphQL data fetchers, and vice versa.
For this reason, we recommend using either the DGS programming model or Spring GraphQL model and not mixing both styles of APIs.
Known limitations include data loader specific features, such as [Scheduled Dispatch] (https://netflix.github.io/dgs/data-loaders/#scheduled-data-loaders-with-dispatch-predicates)and data loader specific metrics that won't work with Spring GraphQL data loaders.
You should be able to use new Spring GraphQL features with the framework, such as schema inspection and any new integrations that are compatible with Spring GraphQL.

We intend iteratively improve the state of teh integration in the coming releases based on usage patterns. 
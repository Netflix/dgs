The DGS Framework now integrates with Spring for GraphQL internally.
Users can continue using the DGS framework as is without additional changes.
Please refer to out [Getting Started guide](./index.md) for more details.
The integration with Spring for GraphQL will allow DGS users to take advantage of any new features that Spring for GraphQL has to offer without having to reimplement it in the framework.
While it is technically possible to mix and match the DGS/Spring-GraphQL programming models, we recommend sticking with the DGS programming model for now, if using the DGS Framework.
By the DGS programming model, we specifically refer to DGS concepts, such as the annotations for setting up data fetchers, data loaders etc.
This will allow users to maintain consistency in the codebase and take full advantage of DGS capabilities.

It is important to note that Spring for GraphQL and the DGS framework offer many similar features that may differ in capabilities. 
For that reason, Spring for GraphQL features work best for Spring for GraphQL style resolvers and vice versa.
A nice benefit to integrating with Spring for GraphQL, is that it paves a way for new features in Spring for GraphQL to be used in the DGS Framework.
These will be available via existing spring-graphql extensions, such as the [Subscription Callback mechanism](https://github.com/apollographql/federation-jvm/pull/354) in the JVM Federation library.

Continue reading to know more about how to use [Spring for GraphQL](https://docs.spring.io/spring-graphql/reference/index.html) with the DGS Framework.

## Background - Two competing frameworks
The DGS Framework provides Java developers with a programming model on top of Spring Boot to create GraphQL services. 
Netflix open-sourced the DGS framework in 2021, and has been the widely adopted GraphQL Java framework by many companies.

Soon after we open-sourced the DGS framework, we learned about parallel efforts by the Spring team to develop a GraphQL framework for Spring Boot. 
The Spring for GraphQL project was in the early stages at the time and provided a low-level of integration with graphql-java. 
Over the past year, however, Spring for GraphQL has matured and is mostly at feature parity with the DGS Framework. 
We now have 2 competing frameworks that solve the same problems for our users.

Today, new users must choose between the DGS Framework or Spring for GraphQL, thus missing out on features available in one framework but not the other. 
This is not an ideal situation for the GraphQL Java community.

For the maintainers of DGS and Spring for GraphQL, it would be far more effective to collaborate on features and improvements instead of having to solve the same problem independently. 
Finally, a unified community would provide us with better channels for feedback.

### Why not just EOL one of the frameworks?
The DGS framework is widely used and plays a vital role in the architecture of many companies, including Netflix. 
Moving away from the framework in favor of Spring-GraphQL would be a costly migration without any real benefits.

From a Spring Framework perspective, it makes sense to have an out-of-the-box GraphQL offering, just like Spring supports REST.

## The way forward
With this integration, you can pull in additional features from Spring for GraphQL. 
We also eliminate the need for part of the DGS code that integrates the framework with Spring MVC/WebFlux, since there isn't much benefit to duplicating low level functionality.

For the near term, the DGS/Spring-Graphql integration will be available as an opt-in feature via a different spring-graphql flavor of the DGS starter. 
We plan to make this the default mode towards the latter part of the year, after we see some level of successful adoption.

![image](./images/dgs_spring_graphql-timeline.jpg#center)

## Technical implementation
Both DGS and Spring-GraphQL are designed with modularity and extensibility in mind. This makes it feasible to integrate the two frameworks. The following diagrams show how the frameworks are integrated at a high level.

Today, the DGS framework looks as follows.
A user uses the DGS programming model, such as `@DgsComponent` and `@DgsQuery` to define data fetchers etc.
A GraphQL query comes in through either WebMVC or WebFlux, and is executed by the `DgsQueryExecutor`, which builds on the graphql-java library to execute the query.
The `DgsQueryExecutor` is also used directly when writing tests.

![image](./images/dgs_architecture.jpg#center)


With the Spring-GraphQL integration, a user can write code with both the DGS programming model and/or the Spring-GraphQL programming model. 
A GraphQL query comes in through WebMVC/WebFlux/RSocket, which Spring-GraphQL now handles. 
The representation of the schema (a `GraphQLSchema` from graphql-java) is created by the DGS framework, and used by both the DGS and Spring for GraphQL components. 
Spring for GraphQL's `ExecutionGraphQLService` now handles the actual query execution, while the DGS `QueryExecutor` becomes a proxy on top of `ExecutionGraphQLService` so that existing test code continues to work.


![image](./images/dgs_spring_graphql-architecture.jpg#center)


## Performance
At Netflix, we tested the DGS/Spring-GraphQL integration on some of our largest services. 
Surprisingly, we uncovered a few performance issues in Spring WebMVC/Spring for GraphQL with this integration. 
The Spring team has quickly addressed these issues, and the performance is now even better compared to baseline performance of Netflix applications with just the regular DGS Framework.

## Notable Changes and Improvements
The good news is that the new integration has been mostly a drop-in replacement, not requiring any breaking code changes for the user. 
Besides the features and changes listed in this section, everything else should continue to work as expected.

### DGS Configuration with Spring for GraphQL
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

New properties for Spring for GraphQL integration are:

| *DGS Property* | *Description*                                    |
|---|-----|
`dgs.graphql.spring.webmvc.asyncdispatch.enabled` | To enable async dispatching for GraphQL requests |

### File Uploads
Support for file uploads will no longer be available by default in the DGS framework. 
This is supported using an external dependency for spring-graphql via [multipart-spring-graphql](https://github.com/nkonev/multipart-spring-graphql).

### Subscriptions over Websockets
Spring for GraphQL supports subscriptions over websockets. 
You will now need to use `org.springframework.boot:spring-boot-starter-websocket`instead of `implementation("com.netflix.graphql.dgs:graphql-dgs-subscriptions-websockets-autoconfigure`.
In addition, you will need to set the following configuration property: `spring.graphql.websocket.path: /graphql`.


### Schema Inspection
You can now inspect your schema using Spring for GraphQL's [schema inspection](https://docs.spring.io/spring-graphql/reference/request-execution.html#execution.graphqlsource.schema-mapping-inspection) feature for DGS data fetchers as well.
You can now inspect schema fields and validate existing DGS data fetcher/and or Spring for GraphQL data fetcher registrations, to check if all schema fields are covered either by an explicitly registered DataFetcher, or a matching Java object property. 
The inspection also performs a reverse check looking for DataFetcher registrations against schema fields that don’t exist.

### Schema resource
In DGS we supported a property `dgs.graphql.schema-json.enabled` which made the schema available a JSON.
With the Spring for GraphQL integration this changes a little bit.
Spring for GraphQL provides a property `spring.graphql.schema.printer.enabled` (disabled by default).
When enabled, it provides the schema in text format (not JSON) on `/graphql/schema`.

### Testing DGS Data Fetchers
For testing individual data fetchers without the web layer, you can continue using the existing testing framework provided via `DgsQueryExecutor` interface. 
We have provided a Spring for GraphQL flavor of the `DgsQueryExecutor` that will continue to work as it does today.
Please refer to our testing docs for more details on writing [data fetcher tests](query-execution-testing.md).

For integration testing with the web layer, you can also use the MockMvc test set up that Spring provides.

You can also use the [recommended `HttpGraphQlTester` with MockMvc available in Spring for GraphQL](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#features.testing.spring-boot-applications.spring-graphql-tests) to achieve the same.
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
By default, Spring for GraphQL uses async dispatch for handling HTTP GraphQL Requests when using WebMVC. 
In this DGS Framework we have turned off this behavior by default to preserve existing functionality, since it requires existing code to be async aware.
This implies servlet filters, tests etc. need to be also async aware.
You can turn on async behavior by setting the `dgs.graphql.spring.webmvc.asyncdispatch.enabled` to true. 

It is worth noting that with the Spring for GraphQL integration, your MockMVC test set up does need to be updated.
Since web request processing is now based on async dispatching mechanism, we now [require explicit handling for this](https://docs.spring.io/spring-framework/reference/testing/spring-mvc-test-framework/async-requests.html) in the test setup.

### Modifying Response headers
Previously, the DGS Framework offered a mechanism to add custom response headers based on the result of processing the GraphQL query using a special `DgsRestController.DGS_RESPONSE_HEADERS_KEY` key.
This is no longer supported. 
The recommended way forward is to use the `WebGraphQlInterceptor` in Spring for GraphQL as described [here](./advanced/intercepting-http-request-response.md))

## Known Gaps and Limitations
At this time, we are lacking support for SSE based subscriptions which is available in the original DGS Framework. 
This is on the roadmap and will be made available in the near future depending on support in spring-graphql. 

In the current state of integration, not all DGS features will work seamlessly for Spring for GraphQL data fetchers, and vice versa.
For this reason, we recommend using either the DGS programming model or Spring for GraphQL model and not mixing both styles of APIs.
Known limitations include data loader specific features, such as [Scheduled Dispatch](https://netflix.github.io/dgs/data-loaders/#scheduled-data-loaders-with-dispatch-predicates) and data loader specific metrics that won't work with Spring for GraphQL data loaders.
You should be able to use new Spring for GraphQL features with the framework, such as schema inspection and any new integrations that are compatible with Spring for GraphQL.

We intend iteratively improve the state of the integration in the coming releases based on usage patterns. 

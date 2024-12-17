GraphQL Subscriptions enable a client to receive updates for a query from the server over time.
Pushing update notifications from the server is a good example.

The DGS framework supports subscriptions out of the box.

## The Server Side Programming Model

In the DGS framework a Subscription is implemented<!-- http://go/pv --> as a data fetcher with the `@DgsSubscription` annotation.
The `@DgsSubscription` is just short-hand for `@DgsData(parentType = "Subscription")`.
The difference with a normal data fetcher is that a subscription *must return a `org.reactivestreams.Publisher`*.

```java
import reactor.core.publisher.Flux;
import org.reactivestreams.Publisher;

@DgsSubscription
public Publisher<Stock> stocks() {
    //Create a never-ending Flux that emits an item every second
    return Flux.interval(Duration.ofSeconds(1)).map({ t -> Stock("NFLX", 500 + t) })
}
```

The `Publisher` interface is from Reactive Streams.
The Spring Framework comes with the Reactor library to work with Reactive Streams.

A complete example can be found [in `SubscriptionDatafetcher.java`](https://github.com/Netflix/dgs-framework/blob/master/graphql-dgs-example-shared/src/main/java/com/netflix/graphql/dgs/example/shared/datafetcher/SubscriptionDataFetcher.java).

## WebSockets

Spring for GraphQL [provides the WebSockets](https://docs.spring.io/spring-graphql/reference/transports.html#server.transports.websocket) transport layer for subscriptions.
The framework supports the `graphql-ws` library which uses the `graphql-transport-ws` [sub-protocol](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md) for Websockets for both WebMVC and Webflux stacks.

To enable WebSockets you need to explicitly set the `spring.graphql.websocket.path` property.

On WebMVC you also have to add the following dependency.
No extra dependency is needed for Webflux.

```groovy
implementation 'org.springframework.boot:spring-boot-starter-websocket'
```

## Server Sent Events

Server Sent Events are also [supported by the Spring for GraphQL](https://docs.spring.io/spring-boot/3.3/reference/web/spring-graphql.html#web.graphql.transports.http-websocket) transport layer, as an alternative to Websockets.
This can be useful for environments where only HTTP is supported, and Websockets is not an option.
No extra configuration or dependencies are needed for SSE.
To sent SSE requests you use the regular `/graphql` endpoint, but with the `text/event-stream` media type.


## Unit Testing Subscriptions

Similar to a "normal" data fetcher test, you use the `DgsQueryExecutor` to execute a query.
Just like a normal query, this results in a `ExecutionResult`.
Instead of returning a result directly in the `getData()` method, a subscription query returns a `Publisher`.
A `Publisher` can be asserted using the [testing capabilities](https://projectreactor.io/docs/core/release/reference/#testing) from Reactor.
Each `onNext` of the `Publisher` is another `ExecutionResult`.
This `ExecutionResult` contains the actual data!

It might take a minute to wrap your head around the concept of this nested `ExecutionResult`, but it gives an excellent way to test Subscriptions, including corner cases.

The following is a simple example of such a test.
The example tests the `stocks` subscription from above.
The `stocks` subscription produces a result every second, so the test uses `VirtualTime` to fast-forward time, without needing to wait in the test.

Also note that the emitted `ExecutionResult` returns a `Map<String, Object>`, and not the Java type that your data fetcher returns.
Use the `Jackson Objectmapper` to convert the map to a Java object.

```java
@SpringBootTest(classes = {SubscriptionDataFetcher.class, DgsExtendedScalarsAutoConfiguration.class, DgsPaginationAutoConfiguration.class, UploadScalar.class})
@EnableDgsTest
class SubscriptionDataFetcherTest {

    @Autowired
    DgsQueryExecutor queryExecutor;

    ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void stocks() {
        ExecutionResult executionResult = queryExecutor.execute("subscription Stocks { stocks { name, price } }");
        Publisher<ExecutionResult> publisher = executionResult.getData();

        VirtualTimeScheduler virtualTimeScheduler = VirtualTimeScheduler.create();
        StepVerifier.withVirtualTime(() -> publisher, 3)
                .expectSubscription()
                .thenRequest(3)
                .assertNext(result -> assertThat(toStock(result).getPrice()).isEqualTo(500))
                .assertNext(result -> assertThat(toStock(result).getPrice()).isEqualTo(501))
                .assertNext(result -> assertThat(toStock(result).getPrice()).isEqualTo(502))
                .thenCancel()
                .verify();
    }

    private Stock toStock(ExecutionResult result) {
        Map<String, Object> data = result.getData();
        return objectMapper.convertValue(data.get("stocks"), Stock.class);
    }
}
```

In this example the subscription works in isolation; it just emits a result every second.
In other scenarios a subscription could depend on something else happening in the system, such as the processing of a mutation.
Such scenarios are easy to set up in a unit test, simply run multiple queries/mutations in your test to see it all work together.

Notice that the unit tests really only test your code.
It doesn't care about transport protocols.
This is exactly what you need for your tests, because your tests should focus on testing your code, not the framework code.

## Integration testing subscriptions

Although most subscription logic should be tested in unit tests, it can be useful to test end-to-end with a client.
This can be achieved with the DGS client, and works well in a `@SpringBootTest` with a random port, and the `WebSocketGraphQLTester`.
The example below starts a subscription, and sends to mutations that should result in updates on the subscription.

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class SubscriptionsGraphQlTesterTest {

    @LocalServerPort
    private int port;

    @Value("http://localhost:${local.server.port}/graphql")
    private String baseUrl;

    private GraphQlTester graphQlTester;


    @BeforeEach
    void setUp() {
        URI url = URI.create(baseUrl);
        this.graphQlTester = WebSocketGraphQlTester.builder(url, new ReactorNettyWebSocketClient()).build();
    }

    @Test
    void stocks() {
        Flux<Stock> result = graphQlTester.document("subscription Stocks { stocks { name, price } }").executeSubscription().toFlux("stocks", Stock.class);

        StepVerifier.create(result)
                .assertNext(res -> Assertions.assertThat(res.getPrice()).isEqualTo(500))
                .assertNext(res -> Assertions.assertThat(res.getPrice()).isEqualTo(501))
                .assertNext(res -> Assertions.assertThat(res.getPrice()).isEqualTo(502))
                .thenCancel()
                .verify();
    }
}

```

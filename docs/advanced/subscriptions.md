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

The GraphQL specification doesn't specify a transport protocol.
WebSockets are the most popular transport protocol however, and are supported by the DGS Framework.

The framework now supports the `graphql-ws` library which uses the `graphql-transport-ws` [sub-protocol](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md) for websockets for both webmvc and webflux stacks.
Apollo now supports the client for this [newer protocol](https://www.apollographql.com/docs/react/data/subscriptions/#setting-up-the-transport) as well.
Note that the newer `graphql-ws` library name is confusing since the deprecated sub-protocol is also named `graphql-ws`.

!!!note
    The deprecated `subscriptions-transport-ws` library, which uses the `graphql-ws` [sub-protocol](https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md) is functional for backwards compatibility.
    However, this implementation will no longer be actively maintained in the framework and we will be dropping support in a future release.


To enable WebSockets support for the WebMVC stack, add the following module to your `build.gradle`:

```groovy
implementation 'com.netflix.graphql.dgs:graphql-dgs-subscriptions-websockets-autoconfigure:latest.release'
```
Please note: DGS does not currently support the newer version of the WebSocket protocol as specified [here](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md)

## Server Sent Events (SSE)

The GraphQL specification doesn't specify a transport protocol.
HTTP2 is coming along which doesn't support WebSockets, instead using something new call [Server Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events), which is also supported by the DGS Framework.
Apollo defines a [sub-protocol](https://github.com/enisdenjo/graphql-sse/blob/master/PROTOCOL.md), which is supported by client libraries and implemented by the DGS framework.

To enable SSE support, add the following module to your `build.gradle`:

```groovy
implementation 'com.netflix.graphql.dgs:graphql-dgs-subscriptions-sse-autoconfigure:latest.release'
```

For WebFlux, the starter already comes with support for websocket subscriptions, so no additional configuration is required.

```groovy
implementation 'com.netflix.graphql.dgs:graphql-dgs-webflux-starter:latest.release'
```

The subscription endpoint is on `/subscriptions`.
Normal GraphQL queries can be sent to `/graphql`, while subscription requests go to `/subscriptions`.

Please see the [graphql-sse](https://github.com/enisdenjo/graphql-sse) package for information on how to set up a client to use SSE.
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

```
@SpringBootTest(classes = {DgsAutoConfiguration.class, SubscriptionDataFetcher.class})
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
This can be achieved with the DGS client, and works well in a `@SpringBootTest` with a random port.
The example below starts a subscription, and sends to mutations that should result in updates on the subscription.
The example uses Websockets, but the same can be done for SSE.
The code for this example can be found in the [example project](https://github.com/Netflix/dgs-examples-java/blob/main/src/test/java/com/example/demo/ReviewSubscriptionIntegrationTest.java).

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class ReviewSubscriptionIntegrationTest {

    @LocalServerPort
    private Integer port;

    private WebSocketGraphQLClient webSocketGraphQLClient;
    private MonoGraphQLClient graphQLClient;
    private MonoRequestExecutor requestExecutor = (url, headers, body) -> WebClient.create(url)
            .post()
            .bodyValue(body)
            .headers(consumer -> headers.forEach(consumer::addAll))
            .exchangeToMono(r -> r.bodyToMono(String.class).map(responseBody -> new HttpResponse(r.rawStatusCode(), responseBody, r.headers().asHttpHeaders())));


    @BeforeEach
    public void setup() {
        webSocketGraphQLClient = new WebSocketGraphQLClient("ws://localhost:" + port + "/subscriptions", new ReactorNettyWebSocketClient());
        graphQLClient = new DefaultGraphQLClient("http://localhost:" + port + "/graphql");
    }

    @Test
    public void testWebSocketSubscription() {
        GraphQLQueryRequest subscriptionRequest = new GraphQLQueryRequest(
                ReviewAddedGraphQLQuery.newRequest().showId(1).build(),
                new ReviewAddedProjectionRoot().starScore()
        );

        GraphQLQueryRequest addReviewMutation1 = new GraphQLQueryRequest(
                AddReviewGraphQLQuery.newRequest().review(SubmittedReview.newBuilder().showId(1).starScore(5).username("DGS User").build()).build(),
                new AddReviewProjectionRoot().starScore()
        );

        GraphQLQueryRequest addReviewMutation2 = new GraphQLQueryRequest(
                AddReviewGraphQLQuery.newRequest().review(SubmittedReview.newBuilder().showId(1).starScore(3).username("DGS User").build()).build(),
                new AddReviewProjectionRoot().starScore()
        );

        Flux<Integer> starScore = webSocketGraphQLClient.reactiveExecuteQuery(subscriptionRequest.serialize(), Collections.emptyMap()).map(r -> r.extractValue("reviewAdded.starScore"));

        StepVerifier.create(starScore)
                .thenAwait(Duration.ofSeconds(1)) //This await is necessary because of issue [#657](https://github.com/Netflix/dgs-framework/issues/657)
                .then(() -> {
                    graphQLClient.reactiveExecuteQuery(addReviewMutation1.serialize(), Collections.emptyMap(), requestExecutor).block();

                })
                .then(() ->
                        graphQLClient.reactiveExecuteQuery(addReviewMutation2.serialize(), Collections.emptyMap(), requestExecutor).block())
                .expectNext(5)
                .expectNext(3)
                .thenCancel()
                .verify();
    }
}
```

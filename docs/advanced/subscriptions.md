GraphQL Subscriptions are used<!-- http://go/pv http://go/use --> to receive updates for a query from the server over time.
A common example is sending<!-- http://go/pv --> update notifications from the server.

Regular GraphQL queries use<!-- http://go/use --> a simple (HTTP) request/response to execute a query.
For subscriptions a connection is kept open.
Currently, we support subscriptions using Websockets. We will  add support for SSE in the future.

## The Server Side Programming Model

In the DGS framework a Subscription is implemented<!-- http://go/pv --> as a data fetcher with the `@DgsData` annotation.
The difference with a normal data fetcher is that a subscription *must return a `org.reactivestreams.Publisher`*.

```java
import reactor.core.publisher.Flux;
import org.reactivestreams.Publisher;
⋮

@DgsData(parentType = "Subscription", field = "stocks")
public Publisher<Stock> stocks() {
    return Flux.interval(Duration.ofSeconds(1)).map({ t -> Tick(t.toString()) })
}
```

The `Publisher` interface is from Reactive Streams.
Flux is the default implementation for Spring.

A complete example can be found [in `SubscriptionDatafetcher.java`](https://github.com/Netflix/dgs-framework/blob/master/graphql-dgs-example-shared/src/main/java/com/netflix/graphql/dgs/example/shared/datafetcher/SubscriptionDataFetcher.java).
Next, a transport implementation must be chosen<!-- http://go/pv -->, which depends on how your app is deployed<!-- http://go/pv -->.

## WebSockets

The subscription endpoint is on `/subscriptions`. 
Normal GraphQL queries can be sent to `/graphql`, while subscription requests go to `/subscriptions`.
The most common transport protocol for Subscriptions in the GraphQL community is WebSockets.  
Apollo defines a [sub-protocol](https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md), which is supported by client libraries and implemented by the DGS framework.
To enable WebSockets support, add the following module to your `build.gradle`:

```groovy
implementation 'com.netflix.graphql.dgs:graphql-dgs-subscriptions-websockets-autoconfigure:latest.release'
```

Apollo client supports WebSockets through a [link](https://www.apollographql.com/docs/link/links/ws/).
Typically, you want to configure Apollo Client with both an HTTP link and a WS link, and [split](https://www.apollographql.com/docs/link/composition/#directional-composition) between them based on the query type.




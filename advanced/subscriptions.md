[GraphQL] Subscriptions are used<!-- http://go/pv http://go/use --> to receive updates for a query from the server over time.
A common example is sending<!-- http://go/pv --> update notifications from the server.

Regular GraphQL queries use<!-- http://go/use --> a simple (HTTP) request/response to execute a query.
For subscriptions a connection is kept open.
Depending on how a DGS is deployed<!-- http://go/pv -->, there are different options to set<!-- http://go/pv --> this up.
The programming model for a DGS developer is the same regardless of the transport protocol, but the correct transport has to be selected<!-- http://go/pv --> to successfully run within Netflix infrastructure.

The following choices are available:

* WebSockets (no [Wall-E] support, internal tooling only)
* SSE (Wall-E supported, apps outside VPN supported)
* [Federated] Gateway (for DGSs behind the federated gateway) 

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

A complete example can be found [in `SubscriptionDatafetcher.kt` from dgs-demo-minimal](https://stash.corp.netflix.com/projects/PX/repos/dgs-demo-minimal/browse/src/main/kotlin/mountainproject/graphql/datafetchers/SubscriptionDatafetcher.kt).

Next, a transport implementation must be chosen<!-- http://go/pv -->, which depends on how your app is deployed<!-- http://go/pv -->.

## WebSockets

The most common transport protocol for Subscriptions in the GraphQL community is WebSockets.  
Apollo defines a [sub-protocol](https://github.com/apollographql/subscriptions-transport-ws/blob/master/PROTOCOL.md), which is supported by client libraries and implemented by the DGS framework.
However, WebSockets are problematic for proxies, including Wall-E.
*If your backend is behind Wall-E, WebSockets are not supported<!-- http://go/pv -->.*

WebSockets work great if your DGS is for an internal tool, where the UI (which can be hosted<!-- http://go/pv --> on [Treasure](https://manuals.netflix.net/view/cloudgateway/mkdocs/master/treasure/overview/)) connects to the backend directly using Eureka DNS.
To enable WebSockets support, add the following module to your `build.gradle`:

```groovy
implementation 'com.netflix.graphql.dgs:graphql-dgs-subscriptions-websockets-autoconfigure:latest.release'
```

Apollo client supports WebSockets through a [link](https://www.apollographql.com/docs/link/links/ws/).
Typically you want to configure Apollo Client with both an HTTP link and a WS link, and [split](https://www.apollographql.com/docs/link/composition/#directional-composition) between them based on the query type.

## SSE

Server Send Events are the right choice if your backend is proxied by Wall-E.

To enable SSE support, add the following module to your `build.gradle`:

```groovy
implementation 'com.netflix.graphql.dgs:graphql-dgs-subscriptions-sse-autoconfigure:latest.release'
```

An internal TypeScript module, [nflx-subscriptions-transport-sse](https://stash.corp.netflix.com/projects/PX/repos/nflx-subscriptions-transport-sse/browse), supports Apollo Link.
This module reimplements an (unmaintained) open source [library](https://github.com/CodeCommission/subscriptions-transport-sse).
The reimplementation was required to support Wall-E.

From a client-side perspective the usage<!-- http://go/use --> is the same as for the WebSocket implementation, just with a different module:

```typescript
import { SubscriptionClient, SSELink} from 'nflx-subscriptions-transport-sse'

const sseClient = new SubscriptionClient(SUBSCRIPTION_ENDPOINT);
const sseLink = new SSELink(sseClient);
const authedClient = authLink && new ApolloClient({
    link: authLink.concat(split((operation) => {
        return operation.operationName === "TicksWatch"}, sseLink, httpLink)),
    cache: new InMemoryCache()
})
```

## Studio Edge Gateway

Studio Edge Gateway supports GraphQL subscriptions.
A client sets up a WSS or SSE connection with the gateway, and the gateway uses a [proprietary protocol](https://stash.corp.netflix.com/projects/STE/repos/studio-gateway/browse/docs/subscriptions.md) based on callbacks with the DGS.

![Gateway Subscriptions architecture](../../../img/gateway-subscriptions.png)

Note that you don't deal with this protocol directly as a DGS developer, the framework takes care of this!
To enable gateway subscriptions, add the following module to your `build.gradle`:

```groovy
implementation 'com.netflix.graphql.dgs:graphql-dgs-subscriptions-gateway-autoconfigure:latest.release'
``` 

The programming model for the DGS developer is exactly the same as described above for SSE/WebSockets, using the Publisher interface with Flux.
The gateway supports both SSE and WebSockets from clients using the client libraries discussed above.

!!!info "Note on gateway subscriptions"
    There are currently a few caveats when using subscriptions through a gateway.
    
    1) Don’t deliver sensitive data through a subscription connection. If you need to deliver sensitive data, the subscription event can trigger the UI to make a followup query.
    
    2) The subscription can’t return a federated type. The same DGS must provide the entire event payload.
    
    3) Expected volume should be <1000 concurrent connections
    
 
--8<-- "docs/reference_links"


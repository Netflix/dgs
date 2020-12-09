The [DGS] framework provides rich support for distributed tracing and logging, out of the box.

### Query Logging

By default, every [DGS] app publishes query logs to [Elasticsearch].
An Elasticsearch cluster contains all query logs of all DGSs.
You do not need to do any additional configuration in order to set this up.
You can use Kibana to view/search the logs:

* [Kibana in Test](http://es_tribe_dgs.us-east-1.dyntest.netflix.net:7103/app/kibana)
* [Kibana in Prod](http://es_tribe_dgs.us-east-1.dynprod.netflix.net:7103/app/kibana)

If your service contains sensitive data that should *not* be visible in logs, you have two options:

1. Use the framework’s log sanitizer to strip out query input variables and query result values.
   Set `dgs.logging.sanitize` to `true`<!-- where/how? -->.
1. Disable query logging entirely.
   Set `dgs.logging.keystone.enabled` to false<!-- where/how? -->.

### Edgar Integration

[Edgar] is a tool that enables request tracing.
In the context of Studio Edge, it creates a trace from the [Studio Edge Gateway] to the different [DGS]s that the gateway uses to resolve a query.
For each DGS it shows which data fetchers were used<!-- http://go/pv http://go/use -->, including timing information.
For each DGS call it also links the query logs (from [Elasticsearch]) to each trace.

You can use Edgar to debug issues for specific (types of) requests and to understand how systems are connected to each other. 
Note that Edgar even captures traces for DGS instances running on localhost, which can be a great tool during development.

!!!abstract "Example"
    The following is an example of an Edgar trace for a query that was resolved by the Headshot DGS and [Maple].

    ![Edgar trace](../../img/edgar-trace1.png) 

    ![Edgar trace](../../img/edgar-trace2.png)

### Edgar Setup


To enable [Edgar] for a new [DGS], provide two pieces of configuration:

First, set the following configuration in your `application.yml`:
```yaml
spring:
  sleuth:
    sampler:
      probability: 1.0
```

!!!note
    If you register your Studio Edge [DGS] by means of the [Reggie](https://manuals.netflix.net/view/studioedge/mkdocs/master/reggie/) tool, that tool will configure Edgar for you automatically and you do not need to take the manual steps described to set up with Edgar UI.

If you did not register your application through reggie, register your application in Edgar by using its [self service UI](https://edgar-studio.dyntest.netflix.net/admin/test/esconfigs/).

| property             | value |
| -------------------- | ----- |
| **Application name** | <code><var>Spinnaker app name</var></code> |
| **Source name**      | `dgs_logging` |
| **Hostname**         | `es_tribe_dgs` |
| **Indices**          | `dgs_logging*` |
| **Log Type**         | `DgsLog` |
| **Span ID**          | `spanId` |
| **Trace ID**         | `traceId` |
| **Timestamp field**  | `ts` |

Make sure to register both for PROD and for TEST.

!!!note
    You do *not* have to set up security groups (as indicated by the UI); this is already done.

### Available Spans

The DGS framework creates several spans by default for each request.

| span ID                                                    | description |
| ---------------------------------------------------------- | ----------- |
| **post /graphql**                                          | This span is created by Spring Boot before the DGS framework starts processing the request. Any time between this span and the `dgs.graphqlendpoint` span are typically filters. |
| **dgs.graphqlendpoint**                                    | Starts when the DGS framework starts processing the request, and includes DGS authz checks. |
| **dgs.queryexecution**                                     | Starts when the query is executed, after input is parsed and context is prepared. |
| **dgs.datafetcher.<var>parentType</var>.<var>field</var>** | Invocation of a datafetcher. The name of the span includes the `parentType` and `field` as specified in `@DgsData`. See the next section about async datafetchers. |
| **dgs.dataloader.<var>name</var>**                         | Invocation of a dataloader. The `name` of the span includes the name of the dataloader. |

### Datafetcher and DataLoader Tracing

By default, the [DGS] framework creates a span for each datafetcher invocation, unless the datafetcher returns a `CompletableFuture` or `CompletionStage`.
Although not always true, the common case for a datafetcher to return `CompletableFuture` or `CompletionStage` is when the datafetcher uses<!-- http://go/use --> a DataLoader.
In the case of batch loading, the datafetcher might be called<!-- http://go/pv --> many times, while the result is only a single invocation<!-- http://go/pv --> to a DataLoader.
In this scenario there isn’t much value in creating<!-- http://go/pv --> spans for each individual datafetcher invocation<!-- http://go/pv -->; instead we just want to see the time spent by the DataLoader.
For this reason, the DGS framework will create no span for datafetchers returning `CompletableFuture` or `CompletionStage`.
However, you can override this behavior by using the `@DgsEnableDataFetcherTracing` annotation.

You can use the same annotation to explicitly disable span creation for a datafetcher.
To do so, pass `false` as an argument to the annotation:

```java hl_lines="2"
@DgsData(parentType="Query", field="someField")
@DgsEnableDataFetcherTracing(false)
public String someDataFetcher() { ... }
```

This is useful for datafetchers that get in-memory data for a specific field.

### Cross Region Requests

[Edgar] keeps track of requests both from a client and server perspective.
A trace starts when a HTTP or [gRPC] client starts a connection.
Another trace starts when the server receives the request and starts processing it.
There can be significant time (up to ~500ms) spent on getting<!-- http://go/pv --> the request from a client to a server, this is specially true when cross region calls are involved<!-- http://go/pv -->.
Other factors are “warming” of a client and its connection pools.
Edgar displays the client portion of a request in a lighter color.
It’s important to understand this difference to know where to look for optimizations.

## Atlas Metrics

Aside from the many metrics already provided out-of-the-box with [Spring Boot], the [DGS] framework adds metrics and tracing.
These metrics work out-of-the-box and don’t require any configuration.

### IPC Metrics with graphql tags
As mentioned earlier, all DGSs have the standard [ipc metrics](https://netflix.github.io/spectator/en/latest/ext/ipc/) that come with Spring Boot apps.
The server call related metrics (ipc.server.call and ipc.server.inflight) also have the following tags for GraphQL queries:

**Tags:**

| tag name              | description |
| --------------------- | ----------- |
| `ipc.protocol`        | Set to `graphql` for GraphQL requests. |
| `ipc.status`          | Set to `success` with most GraphQL requests, except Internal Server Error or Bad request. |
| `ipc.result`          | Set to `success` or `failure` for GraphQL requests. |
| `ipc.status.detail`   | Set to `gql_error` for GraphQL requests. |
| `gql.queryComplexity` | The query complexity computed by graphql-java instrumentation using buckets 5, 10, 25, 50, 100, 200, 500, 1000, 2000, 5000, 10000. |

!!!info "Future Enhancements"
    In the future, the following IPC metric tags will also available: `ipc.client.app`, `ipc.client.cluster`, `ipc.client.asg`, `ipc.client.region`, and `ipc.client.zone`.
    These are currently not propagated by the gateway, but will be supported in the future.

**Example query:**

```
nf.app,requestdetailsdgs,:eq,
name,ipc.server.call,:eq,:and,
ipc.protocol,graphql,:eq,:and,
gql.queryComplexity,3,:eq,:and,
:dist-avg
```

### Error Counter
The error counter counts the number of GraphQL errors encountered during query execution. 

**Name:** `gql.error`

**Type:** Counter

**Tags:**

| tag name          | description |
| ----------------- | ----------- |
| `gql.errorCode`   | The GraphQL error code, such as `VALIDATION`, `INTERNAL`, etc. |
| `gql.errorPath`   | The sanitized query path that resulted in the error. |
| `gql.errorDetail` | Optional flag containing additional details, if present. |


**Example query:**

```
nf.app,mountainprojectdgs,:eq,
name,gql.error,:eq,:and,
:sum,
(,gql.errorCode,),:by
```

### Data Loader Timer

The data loader timer times the execution time for the data loader invocation for a batch of queries.
This is useful if you want to find data loaders that might be responsible for poor query performance. 

**Name:** `gql.dataLoader`

**Type:** Timer

**Tags:**

| tag name              | description |
| --------------------- | ----------- |
| `gql.loaderName`      | The name of the data loader, may or may not be the same as the type of entity. |
| `gql.loaderBatchSize` | The number of queries executed in the batch. |

**Example query:**

```
nf.app,mountainprojectdgs,:eq,
name,gql.dataLoader,:eq,:and,
:max,
(,gql.loaderName,),:by
```

### Data Fetcher Counter

The data fetcher or resolver counter counts the number of invocations of each data fetcher. 
This is useful if you want to find out which data fetchers are used often and which ones aren’t used at all.
Note that this is not available if used<!-- http://go/pv http://go/use --> with a batch loader.

**Name:** `gql.resolver.count`

**Type:** Counter

**Tags:**

| tag name    | description |
| ----------- | ----------- |
| `gql.field` | Name of the data fetcher. This has the `${parentType}.${field}` format as specified in the `@DgsData` annotation. |

**Example query:**

```
nf.app,requestdetailsdgs,:eq,
name,gql.resolver.count,:eq,:and,
:sum,
(,gql.field,),:by
```

### Data Fetcher Timer

The data fetcher timer times the execution time for each data fetcher invocation.
This is useful if you want to find data fetchers that might be responsible for poor query performance.
Note that this metric is not available if used<!-- http://go/pv http://go/use --> with a batch loader.

**Name:** `gql.resolver.time`

**Type:** Timer

**Tags:**

| tag name    | description |
| ----------- | ----------- |
| `gql.field` | Name of the data fetcher. This has the `${parentType}.${field}` format as specified in the `@DgsData` annotation. |

**Example query:**

```
nf.app,requestdetailsdgs,:eq,
name,gql.resolver.time,:eq,:and,
:dist-avg,
(,gql.field,),:by
```

--8<-- "docs/reference_links"


# Adding instrumentation for tracing and logging

It can be extremely valuable to add tracing, metrics and logging to your GraphQL API.
At Netflix we publish tracing spans and metrics for each datafetcher to our distributed tracing/metrics backends, and log queries and query results to our logging backend.
The implementations we use at Netflix are highly specific for our infrastructure, but it's easy to add your own to the framework!

Internally the DGS framework uses [GraphQL Java].
GraphQL Java supports the concept of `instrumentation`.
In the DGS framework we can easily add one or more instrumentation classes by implementing the `graphql.execution.instrumentation.Instrumentation` interface and register the class as `@Component`.
The easiest way to implement the `Instrumentation` interface is to extend `graphql.execution.instrumentation.SimpleInstrumentation`.

The following is an example of an implementation that outputs the execution time for each data fetcher, and the total query execution time, to the logs.
Most likely you would want to replace the log output with writing to your tracing/metrics backend.
Note that the code example accounts for async data fetchers.
If we wouldn't do this, the result for an async data fetcher would always be 0, because the actual processing happens later.

=== "Java"
    ```java

    @Component
    public class ExampleTracingInstrumentation extends SimpleInstrumentation {
        private final static Logger LOGGER = LoggerFactory.getLogger(ExampleTracingInstrumentation.class);

        @Override
        public InstrumentationState createState() {
            return new TracingState();
        }

        @Override
        public InstrumentationContext<ExecutionResult> beginExecution(InstrumentationExecutionParameters parameters) {
            TracingState tracingState = parameters.getInstrumentationState();
            tracingState.startTime = System.currentTimeMillis();
            return super.beginExecution(parameters);
        }

        @Override
        public DataFetcher<?> instrumentDataFetcher(DataFetcher<?> dataFetcher, InstrumentationFieldFetchParameters parameters) {
            // We only care about user code
            if(parameters.isTrivialDataFetcher()) {
                return dataFetcher;
            }

            return environment -> {
                long startTime = System.currentTimeMillis();
                Object result = dataFetcher.get(environment);
                if(result instanceof CompletableFuture) {
                    ((CompletableFuture<?>) result).whenComplete((r, ex) -> {
                        long totalTime = System.currentTimeMillis() - startTime;
                        LOGGER.info("Async datafetcher {} took {}ms", findDatafetcherTag(parameters), totalTime);
                    });
                } else {
                    long totalTime = System.currentTimeMillis() - startTime;
                    LOGGER.info("Datafetcher {} took {}ms", findDatafetcherTag(parameters), totalTime);
                }

                return result;
            };
        }

        @Override
        public CompletableFuture<ExecutionResult> instrumentExecutionResult(ExecutionResult executionResult, InstrumentationExecutionParameters parameters) {
            TracingState tracingState = parameters.getInstrumentationState();
            long totalTime = System.currentTimeMillis() - tracingState.startTime;
            LOGGER.info("Total execution time: {}ms", totalTime);

            return super.instrumentExecutionResult(executionResult, parameters);
        }

        private String findDatafetcherTag(InstrumentationFieldFetchParameters parameters) {
            GraphQLOutputType type = parameters.getExecutionStepInfo().getParent().getType();
            GraphQLObjectType parent;
            if (type instanceof GraphQLNonNull) {
                parent = (GraphQLObjectType) ((GraphQLNonNull) type).getWrappedType();
            } else {
                parent = (GraphQLObjectType) type;
            }

            return  parent.getName() + "." + parameters.getExecutionStepInfo().getPath().getSegmentName();
        }

        static class TracingState implements InstrumentationState {
            long startTime;
        }
    }
    ```
=== "Kotlin"
    ```kotlin
    @Component
    class ExampleTracingInstrumentation: SimpleInstrumentation() {

        val logger : Logger = LoggerFactory.getLogger(ExampleTracingInstrumentation::class.java)

        override fun createState(): InstrumentationState {
            return TraceState()
        }

        override fun beginExecution(parameters: InstrumentationExecutionParameters): InstrumentationContext<ExecutionResult> {
            val state: TraceState = parameters.getInstrumentationState()
            state.traceStartTime = System.currentTimeMillis()

            return super.beginExecution(parameters)
        }

        override fun instrumentDataFetcher(dataFetcher: DataFetcher<*>, parameters: InstrumentationFieldFetchParameters): DataFetcher<*> {
            // We only care about user code
            if(parameters.isTrivialDataFetcher) {
                return dataFetcher
            }

            val dataFetcherName = findDatafetcherTag(parameters)

            return DataFetcher { environment ->
                val startTime = System.currentTimeMillis()
                val result = dataFetcher.get(environment)
                if(result is CompletableFuture<*>) {
                    result.whenComplete { _,_ ->
                        val totalTime = System.currentTimeMillis() - startTime
                        logger.info("Async datafetcher '$dataFetcherName' took ${totalTime}ms")
                    }
                } else {
                    val totalTime = System.currentTimeMillis() - startTime
                    logger.info("Datafetcher '$dataFetcherName': ${totalTime}ms")
                }

                result
            }
        }

        override fun instrumentExecutionResult(executionResult: ExecutionResult, parameters: InstrumentationExecutionParameters): CompletableFuture<ExecutionResult> {
            val state: TraceState = parameters.getInstrumentationState()
            val totalTime = System.currentTimeMillis() - state.traceStartTime
            logger.info("Total execution time: ${totalTime}ms")

            return super.instrumentExecutionResult(executionResult, parameters)
        }

        private fun findDatafetcherTag(parameters: InstrumentationFieldFetchParameters): String {
            val type = parameters.executionStepInfo.parent.type
            val parentType = if (type is GraphQLNonNull) {
                type.wrappedType as GraphQLObjectType
            } else {
                type as GraphQLObjectType
            }

            return "${parentType.name}.${parameters.executionStepInfo.path.segmentName}"
        }

        data class TraceState(var traceStartTime: Long = 0): InstrumentationState
    }
    ```


Datafetcher 'Query.shows': 0ms

Total execution time: 3ms

## Enabling Apollo Tracing

If you want to leverage [Apollo Tracing](https://github.com/apollographql/apollo-tracing), as supported by `graphql-java`, you can create a bean of type {@link TracingInstrumentation}. 
In this example, we added a conditional property on the bean to enable/disable the Apollo Tracing.
This property is enabled by default, but you can turn it off by setting `graphql.tracing.enabled=false` in your application properties.

```java
import graphql.execution.instrumentation.tracing.TracingInstrumentation;

@SpringBootApplication
public class ReviewsDgs {
    @Bean
    @ConditionalOnProperty( prefix = "graphql.tracing", name = "enabled", matchIfMissing = true)
    public Instrumentation tracingInstrumentation(){
        return new TracingInstrumentation();
    }

}
```

For federated tracing, you will need to use the instrumentation provided by [Apollo's jvm federation library](https://github.com/apollographql/federation-jvm#federated-tracing)
```java
import com.apollographql.federation.graphqljava.tracing.FederatedTracingInstrumentation;

@SpringBootApplication
public class ReviewsDgs {

@Bean
@ConditionalOnProperty( prefix = "graphql.tracing", name = "enabled", matchIfMissing = true)
    public Instrumentation tracingInstrumentation(){
        return new FederatedTracingInstrumentation();
    }
}
```

It's important to note that the default behavior in Apollo's jvm federation library is to trace requests, even if the federated gateway does not request it (i.e. the gateway does not add `FEDERATED_TRACING_HEADER_NAME` when forwarding the request). Including the following component in your DGS project will explicitly ask Apollo's jvm federation library to not trace a request in the event that the gateway does not request it.

```java
@Component
public class ApolloFederatedTracingHeaderForwarder implements GraphQLContextContributor {
        @Override
        public void contribute(@NotNull GraphQLContext.Builder builder, @Nullable Map<String, ?> extensions, @Nullable DgsRequestData dgsRequestData) {
            if (dgsRequestData == null || dgsRequestData.getHeaders() == null) {
                return;
            }

            final HttpHeaders headers = dgsRequestData.getHeaders();

            // if the header exists, we should just forward it.
            if (headers.containsKey(FederatedTracingInstrumentation.FEDERATED_TRACING_HEADER_NAME)) {
                builder.put(
                        FederatedTracingInstrumentation.FEDERATED_TRACING_HEADER_NAME,
                        headers
                                .get(FederatedTracingInstrumentation.FEDERATED_TRACING_HEADER_NAME)
                                .stream()
                                .findFirst()
                                .get()
                );
            }  else {
                //otherwise, place a value != "ftv1" so when it gets checked for == ftv1 it fails
                // and trace does not happen.
                builder.put(FederatedTracingInstrumentation.FEDERATED_TRACING_HEADER_NAME, "DO_NOT_TRACE");
            }
        }
}
```

## Metrics Out of The Box

!!! abstract "tl;dr"
    * Supported via the opt-in `graphql-dgs-spring-boot-micrometer` module.
    * Provides specific GraphQL metrics such as `gql.query`, `gql.error`, and `gql.dataLoader`.
    * Supports several backend implementations since it's implemented via [Micrometer].


=== "Gradle Groovy"
    ```groovy
    dependencies {
        implementation 'com.netflix.graphql.dgs:graphql-dgs-spring-boot-micrometer'
    }
    ```
=== "Gradle Kotlin"
    ```kotlin
    dependencies {
        implementation("com.netflix.graphql.dgs:graphql-dgs-spring-boot-micrometer")
    }
    ```
=== "Maven"
    ```xml
    <dependencies>
        <dependency>
            <groupId>com.netflix.graphql.dgs</groupId>
            <artifactId>graphql-dgs-spring-boot-micrometer</artifactId>
        </dependency>
    </dependencies>
    ```

!!! hint
    Note that the version is missing since we assume you are using the latest BOM.
    We recommend you [use the DGS Platform BOM](platform-bom.md) to handle such versions.


### Shared Tags

The following are tags shared across most of the meters.

**Tags:**

| tag name               | values                                      |description |
| ---------------------- | ------------------------------------------- | ---------- |
| `gql.operation`        | QUERY, MUTATION, SUBSCRIPTION are the possible values. These represent the GraphQL operation that is executed.
| `gql.operation.name`   | GraphQL operation name if any, else `anonymous`. Since the cardinality of the value is high it will be [limited](#cardinality-limiter).
| `gql.query.complexity` | one in [5, 10, 20, 50, 100, 200, 500, 1000] | The total number of nodes in the query. Refer to [Query Complexity section](#graphql-query-complexity). for additional information.
| `gql.query.sig.hash`   | [Query Signature Hash](#graphql-query-signature-hash) of the query that was executed. Since the cardinality of the value is high it will be [limited](#cardinality-limiter).


#### GraphQL Query Complexity

The `gql.query.complexity` is typically calculated as 1 + Child's Complexity. The query complexity is valuable to calculate
the cost of a query as this can vary based on input arguments to the query.
The computed value is represented as one of the bucketed values to reduce the cardinality of the metric.

**Example Query:**

```
query {
  viewer {
    repositories(first: 50) {
      edges {
        repository:node {
          name

          issues(first: 10) {
            totalCount
            edges {
              node {
                title
                bodyHTML
              }
            }
          }
        }
      }
    }
  }
}
```

**Example Calculation:**

```
50          = 50 repositories
+
50 x 10     = 500 repository issues

            = 550 total nodes
```


#### GraphQL Query Signature Hash

The **Query Signature** is defined as the tuple of the _GraphQL AST Signature_ of the _GraphQL Document_ and the _GraphQL
AST Signature Hash_. The _GraphQL AST Signature_ of a _GraphQL Document_ is defined as follows:

> A canonical AST which removes excess operations, removes any field aliases,
> hides literal values and sorts the result into a canonical query
Ref [graphql-java](https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/language/AstSignature.java#L35-L41)

The **GraphQL AST Signature Hash** is the Hex 256 SHA string produced by encoding the *AST Signature*.
While we can't tag a metric by its signature, due its length, we can use the *hash*, as now expressed by the
`gql.query.sig.hash` tag.

There are a few configuration parameters that can change the behavior of the `gql.query.sig.hash` tag.

* `management.metrics.dgs-graphql.query-signature.enabled`:
   Defaulting to `true`, it enables the calculation of the  *GQL Query Signature*. The `gql.query.sig.hash` will express the _GQL Query Signature Hash_.
* `management.metrics.dgs-graphql.query-signature.caching.enabled`:
   Defaulting to `true`, it will cache the *GQL Query Signature*. If set to `false` it will just disable the cache but will
   not turn the calculation of the signature off. If you want to turn such calculation off use the
   `management.metrics.dgs-graphql.query-signature.enabled` property.


#### Cardinality Limiter

The _cardinality_ of a given tag, the number of different values that a tag can express, can be problematic to
servers supporting metrics. In order to prevent the cardinality of some of the tags supported out of the box there
are some limiters by default. The limited tag values will only _see_ the first 100 different values by default,
from there new values will be expressed as `--others--`.

You can change the limiter via the following configuration:

* `management.metrics.dgs-graphql.tags.limiter.limit`: Defaults to`100`, sets the number of different values expressed per limited tag.

Not all tags are limited, currently, only following are:

* `gql.operation.name`
* `gql.query.sig.hash`



### Query Timer: gql.query

Captures the elapsed time that a given GraphQL query, or mutation, takes.

**Name:** `gql.query`

**Tags:**

| tag name               | values                                      |description |
| ---------------------- | ------------------------------------------- | ---------- |
| `outcome`              | `success` or `failure`                      | Result of the operation, as defined by the [ExecutionResult].


### Error Counter: gql.error

Captures the number of GraphQL errors encountered during query execution of a query or mutation.
Remember that one _graphql_ request can have multiple errors.

**Name:** `gql.error`

**Tags:**

| tag name          | description |
| ----------------- | ----------- |
| `gql.errorCode`   | The GraphQL error code, such as `VALIDATION`, `INTERNAL`, etc.|
| `gql.path`        | The sanitized query path that resulted in the error.     |
| `gql.errorDetail` | Optional flag containing additional details, if present. |

### Data Loader Timer: gql.dataLoader

Captures the elapsed time for a data loader invocation for a batch of queries.
This is useful if you want to find data loaders that might be responsible for poor query performance.

**Name:** `gql.dataLoader`

**Tags:**

| tag name              | description |
| --------------------- | ----------- |
| `gql.loaderName`      | The name of the data loader, may or may not be the same as the type of entity. |
| `gql.loaderBatchSize` | The number of queries executed in the batch. |


### Data Fetcher Timer: gql.resolver

Captures the elapsed time of each data fetcher invocation.
This is useful if you want to find data fetchers that might be responsible for poor query performance.
That said, there might be times where you want to remove a _data fetcher_ from being measured/included in this meter.
You can do so by annotating the method with `@DgsEnableDataFetcherInstrumentation(false)`.


!!! info
    This metric is not available if:

    * The data is resolved via a Batch Loader.
    * The method is annotated with `@DgsEnableDataFetcherInstrumentation(false)`.
    * The DataFetcher is [TrivialDataFetcher]. A _trivial DataFetcher_ is one that simply maps data from an object to a field.
      This is defined directly in `graphql-java`.

[TrivialDataFetcher]: https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/TrivialDataFetcher.java

**Name:** `gql.resolver`

**Tags:**

| tag name    | description |
| ----------- | ----------- |
| `gql.field` | Name of the data fetcher. This has the `${parentType}.${field}` format as specified in the `@DgsData` annotation. |


#### Data Fetcher Timer as a Counter

The data fetcher, or resolver, timer can be used as a counter as well.
If used in this manner it will reflect the number of invocations of each data fetcher.
This is useful if you want to find out which data fetchers are used often.

### Further Tag Customization

You can customize the tags applied to the metrics above by providing *beans* that implement the following functional interfaces.

| Interface                    | Description |
| ---------------------------- | ----------- |
| `DgsContextualTagCustomizer` | Used to add common, contextual tags. Example of these could be used to describe the deployment environment, application profile, application version, etc |
| `DgsExecutionTagCustomizer`  | Used to add tags specific to the [ExecutionResult] of the query. The [SimpleGqlOutcomeTagCustomizer] is an example of this.|
| `DgsFieldFetchTagCustomizer` | Used to add tags specific to the execution of _data fetchers_. The [SimpleGqlOutcomeTagCustomizer] is an example of this as well.|             |


### Additional Metrics Configuration

* `management.metrics.dgs-graphql.enabled`: Enables the metrics provided out of the box; **defaults** to `true`.
* `management.metrics.dgs-graphql.tag-customizers.outcome.enabled`: Enables the _tag customizer_ that will label the `gql.query` and `gql.resolver` timers with an `outcome` reflecting
   the result of the GraphQL outcome, either `success` or `failure`; **defaults** to `true`.
* `management.metrics.dgs-graphql.data-loader-instrumentation.enabled`: Enables instrumentation of _data loaders_; **defaults** to `true`.

---

[Micrometer]: https://micrometer.io/
[Micrometer Atlas]: https://micrometer.io/docs/registry/atlas
[Atlas]: https://github.com/Netflix/atlas/wiki/Getting-Started
[ErrorType]: https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/ErrorType.java
[ExecutionResult]: https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/ExecutionResult.java
[SimpleGqlOutcomeTagCustomizer]: https://github.com/Netflix/dgs-framework/blob/master/graphql-dgs-spring-boot-micrometer/src/main/kotlin/com/netflix/graphql/dgs/metrics/micrometer/tagging/SimpleGqlOutcomeTagCustomizer.kt
[GraphQL Java]: https://www.graphql-java.com

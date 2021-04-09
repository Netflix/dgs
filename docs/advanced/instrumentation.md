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


## Metrics Out of The Box

!!! abstract "tl;dr"

    * Supported vi the opt-in `graphql-dgs-spring-boot-micrometer` module.
    * Provides specific GraphQL metrics such as `gql.query`, `gql.error`, and `gql.dataLoader`.
    * Backed by [Micrometer], it supports several backends.


=== "Gradle Groovy"
    ```groovy
    dependencies {
        implementation 'com.netflix.graphql.dgs:graphql-dgs-spring-boot-micrometer:3.+'
    }
    ```
=== "Gradle Kotlin"
    ```kotlin
    dependencies {
        implementation("com.netflix.graphql.dgs:graphql-dgs-spring-boot-micrometer:3.+")
    }
    ```
=== "Maven"
    ```xml
    <dependencies>
        <dependency>
            <groupId>com.netflix.graphql.dgs</groupId>
            <artifactId>graphql-dgs-spring-boot-micrometer</artifactId>
            <version>3.+</version>
        <dependency>
    </dependencies>
    ```
!!! warning
    The version used above is just an example. Please verify the verison you want to use by visiting
    the [Release page](https://github.com/Netflix/dgs-framework/releases).


### Query Timer: gql.query

Captures the elapsed time that a given GraphQL query, or mutation, takes.

**Name:** `gql.query`

**Tags:**

| tag name     | values                 |description |
| ------------ | ---------------------- | ---------- |
| `outcome`    | `success` or `failure` | Result of the operation, as defined by the [ExecutionResult].


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


!!! warning
    This metric is not available if:

    * The data is resolved via a Batch Loader.
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


### Configuration

#### management.metrics.dgs-graphql.enabled

Enables the metrics provided out of the box.
**Defaults** to `true`.

#### management.metrics.dgs-graphql.tag-customizers.outcome.enabled

Enables the _tag customizer_ that will label the `gql.query` and `gql.resolver` timers with an `outcome` reflecting
the result of the GraphQL outcome, either `success` or `failure`.
Note that in GraphQL, vs REST, an [HTTP OK](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/200) is not
necessarily a response without errors. To evaluate the success of a response we needs to consider if there are any
GraphQL errors as part of the response payload. In other words, you will get an HTTP 200 response even if the
GraphQL response has errors.


**Defaults** to `true`.

#### management.metrics.dgs-graphql.data-loader-instrumentation.enabled

Enables instrumentation of _data loaders_.
**Defaults** to `true`.

---

[Micrometer]: https://micrometer.io/
[Micrometer Atlas]: https://micrometer.io/docs/registry/atlas
[Atlas]: https://github.com/Netflix/atlas/wiki/Getting-Started
[ErrorType]: https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/ErrorType.java
[ExecutionResult]: https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/ExecutionResult.java
[SimpleGqlOutcomeTagCustomizer]: https://github.com/Netflix/dgs-framework/blob/master/graphql-dgs-spring-boot-micrometer/src/main/kotlin/com/netflix/graphql/dgs/metrics/micrometer/tagging/SimpleGqlOutcomeTagCustomizer.kt
[GraphQL Java]: https://www.graphql-java.com

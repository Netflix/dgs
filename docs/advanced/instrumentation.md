# Adding instrumentation for tracing and logging

It can be extremely valuable to add tracing, metrics and logging to your GraphQL API.
At Netflix we publish tracing spans and metrics for each datafetcher to our distributed tracing/metrics backends, and log queries and query results to our logging backend.
The implementations we use at Netflix are highly specific for our infrastructure, but it's easy to add your own to the framework!

Internally the DGS framework uses [GraphQL Java](https://www.graphql-java.com).
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
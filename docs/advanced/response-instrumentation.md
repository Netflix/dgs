# Response Instrumentation
The DGS framework internally uses [GraphQL Java].
GraphQL Java supports the concept of `instrumentation` that can be used to perform additional operations (tracing, logging), and instrument the graphql query and response as needed.
The DGS framework makes it easy to add one or more instrumentation classes by implementing the `graphql.execution.instrumentation.Instrumentation` interface and registering the class as `@Component`.
The most common method  to implement an `Instrumentation` interface is to extend `graphql.execution.instrumentation.SimpleInstrumentation`.

Leveraging the concept of an instrumentation class, the framework offers the ability to add response headers to the outgoing response via setting the extensions field in the `ExecutionResult` for MVC. 
This provides a hook to update the response headers based on the result of the `graphql` query execution.
The instrumentation class provides access to `graphql` specific state related to the query.
Simply add a map of headers using `DgsRestController.DGS_RESPONSE_HEADERS_KEY` to the extensions field of the result, and the framework handles adding those to the outgoing response. 
This is a special key and is consumed by the framework, and thus will not appear in the final `extensions` field as part of the result.


#### Example:

```java  
@Component
public class MyInstrumentation extends SimpleInstrumentation {
    @Override
    public CompletableFuture<ExecutionResult> instrumentExecutionResult(ExecutionResult executionResult, InstrumentationExecutionParameters parameters) {
        HashMap<Object, Object> extensions = new HashMap<>();
        if(executionResult.getExtensions() != null) {
            extensions.putAll(executionResult.getExtensions());
        }

        Map<String, String> responseHeaders = new HashMap<>();
        responseHeaders.put("myHeader", "hello");
        extensions.put(DgsRestController.DGS_RESPONSE_HEADERS_KEY, responseHeaders);

        return super.instrumentExecutionResult(new ExecutionResultImpl(executionResult.getData(), executionResult.getErrors(), extensions), parameters);
    }
}
```

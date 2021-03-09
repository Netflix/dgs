
Each data fetcher in [GraphQL] Java has a context.
A data fetcher gets access to its context by calling [`DataFetchingEnvironment.getContext()`](https://javadoc.io/doc/com.graphql-java/graphql-java/12.0/graphql/schema/DataFetchingEnvironment.html#getContext--).
This is a common mechanism to pass request context to data fetchers and data loaders.
The DGS framework has its own [`DgsContext`](https://github.com/Netflix/dgs-framework/blob/master/graphql-dgs/src/main/kotlin/com/netflix/graphql/dgs/context/DgsContext.kt) implementation, which is used<!-- http://go/pv --> for log instrumentation among other things.
It is designed<!-- http://go/pv --> in such a way that you can extend it with your own custom context.

To create a custom context, implement a Spring bean of type `DgsCustomContextBuilder`.
Write the `build()` method so that it creates an instance of the type that represents your custom context object:

```java
@Component
public class MyContextBuilder implements DgsCustomContextBuilder<MyContext> {
    @Override
    public MyContext build() {
        return new MyContext();
    }
}

public class MyContext {
    private final String customState = "Custom state!";

    public String getCustomState() {
        return customState;
    }
}
```

A data fetcher can now retrieve the context by calling the `getCustomContext()` method:

```java
@DgsData(parentType = "Query", field = "withContext")
public String withContext(DataFetchingEnvironment dfe) {
    MyContext customContext = DgsContext.getCustomContext(dfe);
    return customContext.getCustomState();
}
```

Similarly it<!-- "it" is ambiguous here --> can be used<!-- http://go/pv --> in a DataLoader.

```java
@DgsDataLoader(name = "exampleLoaderWithContext")
public class ExampleLoaderWithContext implements BatchLoaderWithContext<String, String> {
    @Override
    public CompletionStage<List<String>> load(List<String> keys, BatchLoaderEnvironment environment) {

        MyContext context = DgsContext.getCustomContext(environment);

        return CompletableFuture.supplyAsync(() -> keys.stream().map(key -> context.getCustomState() + " " + key).collect(Collectors.toList()));
    }
}
```



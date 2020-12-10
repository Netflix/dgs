
If you have cyclical queries in your graph, you may want to limit the possible query depth.

You can use instrumentation to monitor and restrict query depth.
In [`graphql-java`](https://github.com/graphql-java), you can find an implementation for this in [`MaxQueryDepthInstrumentation.java`](https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/analysis/MaxQueryDepthInstrumentation.java).

If you register an `Instrumentation` class as a Spring bean, the DGS framework will pick it up automatically.
For example:

```spring
@Bean
public Instrumentation
maxQueryDepthInstrumentation() {
   return new MaxQueryDepthInstrumentation(5);
}
```

--8<-- "docs/reference_links"


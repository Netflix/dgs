This guide is about how to provide mock data for data fetchers.
There are two primary reasons to do so:

1. Provide example data that UI teams can use while the data fetcher is under development.
   This is useful during schema design.
2. Provide stable test data for UI teams to write their tests against.

An argument can be made that this type of mock data should live in the UI code.
It’s for their tests after all.
However, by pulling it into the DGS, the owners of the data can provide test data that can be used by many teams.
The two approaches are also not mutually exclusive.

## [GraphQL] Mocking

The library in the DGS framework supports:

1. returning static data from mocks
2. returning generated data for simple types (like String fields)

The library is modular, so you can use it for a variety of workflows and use cases.

The mocking framework is already part of the DGS framework.
All you need to provide is one or more `MockProvider` implementations.
`MockProvider` is an interface with a `Map<String, Object> provide()` method.
Each key in the `Map` is a field in the [GraphQL] schema, which can be several levels deep.
The value in the `Map` is whatever mock data you want to return for this key.

### Example

Create a `MockProvider` that provides mock data for the `hello` field you created in the getting started [tutorial](../getting-started.md):

```java
@Component
public class HelloMockProvider implements MockProvider {
    @NotNull
    @Override
    public Map<String, Object> provide() {
        Map<String, Object> mock = new HashMap<>();
        mock.put("hello", "Mocked hello response");
        return mock;
    }
}
```

If you run the application again and test the `hello` query, you will see that it now returns the mock data.

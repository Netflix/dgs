
In the [getting started](../docs/tutorial.md) tutorial you’ll learn how to write tests for a data fetcher.
This is useful for the developer of the data fetcher. 
However, what should you do if a UI developer wants to test against your schema? 
How do they test against a stable set of data?

This guide is about how to provide mock data for data fetchers.
There are two primary reasons to do so:

1. Provide example data that UI teams can use while the data fetcher is under development.
   This is useful during schema design.
2. Provide stable test data for UI teams to write their tests against.

An argument can be made that this type of mock data should live in the UI code.
It’s for their tests after all.
However, by pulling it into the [DGS], the owners of the data can provide test data that can be used by many teams.
The two approaches are also not mutually exclusive.

## [GraphQL] Mocking

The library in the [DGS] framework supports:

1. returning static data from mocks
2. returning generated data for simple types (like String fields)
3. remotely enabling mocks for a [Meechum] user by using [Simone]

The library is modular, so you can use it for a variety of workflows and use cases.

The mocking framework is already part of the DGS framework.
All you need to provide is one or more `MockProvider` implementations.
`MockProvider` is an interface with a `Map<String, Object> provide()` method.
Each key in the `Map` is a field in the [GraphQL] schema, which can be several levels deep.
The value in the `Map` is whatever mock data you want to return for this key.

### Example

Create a `MockProvider` that provides mock data for the `hello` field you created in the getting started [tutorial](../docs/tutorial.md):

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
This is useful while a data fetcher isn’t implemented yet, but the true power comes from enabling<!-- http://go/pv --> the mocks remotely.

### [Simone] Integration

Simone is a distributed testing tool that testers use in the streaming world for end-to-end testing and device certification.
A micro-service integrates with the Simone client, and a tester can activate test behavior by creating a `Variant` by using either the UI or an API.
By creating `Variant`s, a tester can trigger special behavior in a service in order to validate very specific scenarios.

The [DGS] framework integrates with Simone to enable a `MockProvider` when a `Variant` is active for a specific user email address.
This way, a tester or UI developer can enable mock behavior for a specific account, while the mock data itself is owned by the DGS owner.

Change the `HelloMockProvider` implementation to use the Simone integration as follows:

```java
@Component
public class HelloMockProvider implements MockProvider {
    @Autowired
    SimoneSsoMockProvider simoneSsoMockProvider;

    public Map<String, Object> provide() {
        return simoneSsoMockProvider.provide((identity, variant) -> {
            HashMap<String, Object> mocks = Maps.newHashMap();

            mocks.put("hello", "Hello from Simone, " + identity);

            return mocks;
        }, SsoCaller::getName);
    }
}
```

`SimoneSsoMockProvider` is a thin wrapper for Simone.
It picks up the `SsoCaller` that’s available in [Spring Boot], and checks Simone to see if a variant is active for the caller’s email address.
The code in the lambda passed to the `provide` method only executes if a variant for the user is available.
Before you create such a variant and test it out, you must perform some configuration for the Simone [gRPC] client.

```yaml
grpc:
  client:
    okja:
      OkjaService:
        channel:
          target: eureka:///okjagrpctest
          usePlaintext: false
          negotiationType: TLS
          sslContextFactory: metatron
          targetApplication: okja
      interceptor:
        retry:
          default:
            maxRetries: 3
            statuses: UNAVAILABLE
dgs:
  mocking:
    simone:
      enabled: true
```

With the code and configuration in place, the next query you send to `hello` should<!-- http://go/should --> give the same result as it previously did. 
Simone will only become active after you create a variant.

The easiest way to create a variant is to use the Simone UI: [go/simone](https://go/simone).

![Simone screenshot](../../../img/graphql-simone.png)

Click **Variants** → **Create Variant** and select the **TEST** environment.
A form appears that lets you create a variant.
Select `com.netflix.graphql.mocking` as the **Template**.
**Eviction Count** indicates the number of times Simone will apply this variant before it expires.
For now, set it to 10, so that you can run a few tests.
The **Correlation Id** is an ID that you can pick, which you can later use to search Simone’s variant tracing.
The **Trigger** type is `com.netflix.simone.trigger.esnExactMatch`.
An **ESN** is something from the streaming world; the DGS framework uses the user’s email address instead.
Set the value of **ESN** to your [Meechum] email address.
After you create the variant by clicking **Create**, the next query you send to `hello` should<!-- http://go/should --> generate a response from the Simone mock.

![Simone video](../../../img/graphql-simone.gif)

The `com.netflix.graphql.mocking` template allows for an arbitrary object with key/values to be passed<!-- http://go/pv --> as argument data when creating<!-- http://go/pv --> the variant.
The variant arguments are available<!-- http://go/pv --> in code, and this allows for some dynamic behavior in mocks.
The following is an example that uses Jackson to parse the argument data:

```java
@Component
public class HelloMockProvider implements MockProvider {
    @Autowired
    Optional<SimoneSsoMockProvider> simoneSsoMockProvider;

    public Map<String, Object> provide() {
        return simoneSsoMockProvider.map(ssoMockProvider -> ssoMockProvider.provide((identity, variant) -> {
            HashMap<String, Object> mocks = Maps.newHashMap();

            ObjectMapper mapper = new ObjectMapper();
            try {
                Map<String, String> args = mapper.readValue(variant.getArgumentData(), new TypeReference<Map<String, String>>() {
                });

                mocks.put("hello", "Hello from Simone, " + identity + ". MyArg: " + args.get("myarg"));
                System.out.println(args);
            } catch (IOException e) {
                e.printStackTrace();
            }


            return mocks;
        }, SsoCaller::getName)).orElse(Collections.emptyMap());
    }
}
```

To learn more about Simone, and options to use its APIs to create Variants, refer to the [Simone Documentation](http://manuals.netflix.net/view/simone/mkdocs/master/testers-java-sdk3/).

### Mock Return Types

In the previous examples you have implemented mocks with static data, where the `provide()` method returns a static set of key/values.
In addition to hardcoded values, the mock framework also supports returning a data fetcher (which gives access to the `DataFetchingEnvironment`) and partly-generated data.

The following example mocks the `hello` field, but doesn’t provide a value.
The mock framework will generate data based on the object type of the field defined in the schema.
This is also an effective way to mock arrays of data.
When the schema defines a field as an array, the mock framework generates an array of variable size.

```java
public Map<String, Object> provide() {
    Map<String, Object> mocks = new HashMap<>();

    mocks.put("hello", null);

    return mocks;
}
```

You can also provide a data fetcher as the value of the mock.
This gives access to the `DataFetchingEnvironment`, so that you can, for example, use arguments in the generated mock data:

```java
public Map<String, Object> provide() {
    Map<String, Object> mocks = new HashMap<>();

    DataFetcher datafetcher = (dataFetchingEnvironment) -> "Hello from mock, " + dataFetchingEnvironment.getArgument("name");

    mocks.put("hello", datafetcher);

    return mocks;
}
``` 

--8<-- "docs/reference_links"



It is easy to add a custom scalar type in the DGS framework:
Create a class that implements the `graphql.schema.Coercing` interface and annotate it with the `@DgsScalar` annotation.
Also make sure the scalar type is defined in your [GraphQL] schema!

For example, this is a simple `LocalDateTime` implementation:

```java
@DgsScalar(name="DateTime")
public class DateTimeScalar implements Coercing<LocalDateTime, String> {
    @Override
    public String serialize(Object dataFetcherResult) throws CoercingSerializeException {
        if (dataFetcherResult instanceof LocalDateTime) {
            return ((LocalDateTime) dataFetcherResult).format(DateTimeFormatter.ISO_DATE_TIME);
        } else {
            throw new CoercingSerializeException("Not a valid DateTime");
        }
    }

    @Override
    public LocalDateTime parseValue(Object input) throws CoercingParseValueException {
        return LocalDateTime.parse(input.toString(), DateTimeFormatter.ISO_DATE_TIME);
    }

    @Override
    public LocalDateTime parseLiteral(Object input) throws CoercingParseLiteralException {
        if (input instanceof StringValue) {
            return LocalDateTime.parse(((StringValue) input).getValue(), DateTimeFormatter.ISO_DATE_TIME);
        }

        throw new CoercingParseLiteralException("Value is not a valid ISO date time");
    }
}
```

**Schema:**
```graphql
scalar DateTime
```

## Registering Custom Scalars

In more recent versions of `graphql-java` (>v15.0) [some scalars](https://github.com/graphql-java/graphql-java-extended-scalars),
most notably the `Long` scalar, are no longer available by default.
These are non standard scalar that are difficult for clients (e.g. JavaScript) to handle reliably.
As a result of the deprecation, you will need to add them explicitly, and to do this you have a few options.

!!! tip
    Go to the [graphql-java-extended-scalars project page](https://github.com/graphql-java/graphql-java-extended-scalars)
    to see the full list of scalars supported by this library. There you will also find examples of the scalars used
    in both _schemas_ as well as example queries.

### Automatically Register Scalar Extensions via graphql-dgs-extended-scalars

The DGS Framework, as of version 3.9.2, has the `graphql-dgs-extended-scalars` module. This module provides an
_auto-configuration_ that will register automatically the scalar extensions defined in the
`com.graphql-java:graphql-java-extended-scalars` library. To use it you need to...

1. Add the `com.netflix.graphql.dgs:graphql-dgs-extended-scalars` dependency to your build. If you are using the
   [DGS BOM] you don't need to specify a version for it, the BOM will recommend one.
1. Define the scalar in your schema

You also need to define explicit [type mapping](https://netflix.github.io/dgs/generating-code-from-schema/).   
Example to use `Url` and `PositiveInt` scalars.

Add this to `build.gradle`
```
generateJava {
    typeMapping = ["Url" : "java.net.URL", "PositiveInt" : "java.lang.Integer"]
}
```

Define scalar on your schema

```
scalar Url
scalar PositiveInt

type SampleScalar {
  theUrl: Url
  thePositiveInt: PositiveInt
}
```

Other mapping available on [extended scalars doc](https://github.com/graphql-java/graphql-java-extended-scalars)

The `graphql-java-extended-scalars` module offers a few knobs you can use to turn off registration.


| Property                                          | Description |
| ------------------------------------------------- | ----------- |
| dgs.graphql.extensions.scalars.time-dates.enabled | If set to `false`, it will not register the DateTime, Date, and Time scalar extensions.           |
| dgs.graphql.extensions.scalars.objects.enabled    | If set to `false`, it will not register the Object, Json, Url, and Locale scalar extensions.      |
| dgs.graphql.extensions.scalars.numbers.enabled    | If set to `false`, it will not register all numeric scalar extensions such as PositiveInt, NegativeInt, etc.|
| dgs.graphql.extensions.scalars.chars.enabled      | If set to `false`, it will not register the GraphQLChar extension. |
| dgs.graphql.extensions.scalars.enabled            | If set to `false`, it will disable automatic registration of all of the above. |


### Register Scalar Extensions via DgsRuntimeWiring

You can also register the Scalar Extensions manually. To do so you need to...

1. Add the `com.graphql-java:graphql-java-extended-scalars` dependency to your build. If you are using the
   [DGS BOM] you don't need to specify a version for it, the BOM will recommend one.
1. Define the scalar in your schema
1. Register the scalar.

Here is an example of how you would set that up:

**Schema:**
```graphql
scalar Long
```
You can register the `Long` scalar manually with the DGS Framework as shown here:
```java
@DgsComponent
public class LongScalarRegistration {
    @DgsRuntimeWiring
    public RuntimeWiring.Builder addScalar(RuntimeWiring.Builder builder) {
        return builder.scalar(Scalars.GraphQLLong);
    }
}
```


[DGS BOM]: ./advanced/platform-bom.md

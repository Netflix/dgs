
It is easy to add a custom scalar type in the [DGS] framework:
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

## Shared Scalars and Types
The Studio Edge team is designing a set of common shared scalars and types for Studio Edge.
See [Schema Best Practices: Custom Scalars](http://manuals.netflix.net/view/studioedge/mkdocs/master/best-practices/#custom-scalars) at the Studio Edge documentation for more details.



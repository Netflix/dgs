
## Configure the location of the GraphQL Schema Files

You can configure the location of your GraphQL schema files via the `dgs.graphql.schema-locations` property.
By default it will attempt to load them from the `schema` directory via the _Classpath_, i.e. using `classpath*:schema/**/*.graphql*`.
Let's go through an example, let's say you want to change the directory from being `schema` to `graphql-schemas`,
you would define your configuration as follows:

```yaml
dgs:
    graphql:
        schema-locations:
            - classpath*:graphql-schemas/**/*.graphql*
```

Now, if you want to add additional locations to look for the GraphQL Schema files you an add them to the list.
For example, let's say we want to also look into your `graphql-experimental-schemas`:

```yaml
dgs:
    graphql:
        schema-locations:
            - classpath*:graphql-schemas/**/*.graphql*
            - classpath*:graphql-experimental-schemas/**/*.graphql*
```


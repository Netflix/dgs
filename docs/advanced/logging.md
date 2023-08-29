# Disabling logging of sensitive information

The [notprivacysafe SLF4J logger](https://github.com/graphql-java/graphql-java/blob/a54bb43936a3b68fe44ee55032e407c8a703c263/src/main/java/graphql/GraphQL.java#L94) from graphql-java provides logging at different steps of the query execution process.

By default, all errors and invalid queries are logged by graphql-java. To disable this, include the following in your application.yml to turn off the logger:
```yaml
logging:
  level:
    notprivacysafe: OFF
```

When set to the debug level, the notprivacysafe logger will also log at the query execution, parsing, and validation steps:
```yaml
logging:
  level:
    notprivacysafe: DEBUG
```

[This graphql-java issue](https://github.com/graphql-java/graphql-java/issues/1585#issuecomment-511258821) adds support for configuring the logger.


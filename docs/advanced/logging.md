# Configuring logging level

The [notprivacysafe SLF4J logger](https://github.com/graphql-java/graphql-java/blob/a54bb43936a3b68fe44ee55032e407c8a703c263/src/main/java/graphql/GraphQL.java#L94) from graphql-java provides logging at different steps of the query execution process.

By default, all errors and invalid queries are logged. To disable this, include the following in your application.yml to disable the logger:
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

Read more about SLF4J logging levels [here](https://www.slf4j.org/api/org/apache/log4j/Level.html).


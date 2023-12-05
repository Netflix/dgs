## Configuration

### Core Properties

| Name                                                            | Type     | Default                            | Description                                                                                                                     |
|-----------------------------------------------------------------|----------|------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| dgs.graphql.path                                                | String   | `"/graphql"`                       | Path to the endpoint that will serve GraphQL requests.                                                                          |
| dgs.graphql.introspection.enabled                               | Boolean  | `true`                             | Enables graphql introspection functionality.                                                                                    |
| dgs.graphql.schema-json.enabled                                 | Boolean  | `true`                             | Enables schema-json endpoint functionality.                                                                                     |
| dgs.graphql.schema-json.path                                    | String   | `"/schema.json"`                   | Path to the schema-json endpoint without trailing slash.                                                                        |
| dgs.graphql.schema-locations                                    | [String] | `"classpath*:schema/**/*.graphql*"` | Location of the GraphQL schema files.                                                                                           |
| dgs.graphql.graphiql.enabled                                    | Boolean  | `true`                             | Enables GraphiQL functionality.                                                                                                 |
| dgs.graphql.graphiql.path                                       | String   | `"/graphiql"`                      | Path to the GraphiQL endpoint without trailing slash.                                                                           |
| dgs.graphql.graphiql.title                                      | String   | `"Simple GraphiQL Example"`        | Title of the GraphiQL page                                                                                                      |
| dgs.graphql.enable-entity-fetcher-custom-scalar-parsing         | Boolean  | `false`                            | Enables the bug fix for entity fetcher custom scalar parsing. This will eventually be enabled by default.                       |
| dgs.graphql.dataloader.ticker-mode-enabled                      | Boolean  | `false`                            | Enables the ticker mode for scheduling data loader dispatches.                                                                  |
| dgs.graphql.dataloader.schedule-duration                        | String   | `10ms`                             | Set the schedule for scheduling dispatch predicate checks.                                                                      |
| dgs.graphql.preparsed-document-provider.enabled                 | Boolean  | `false`                            | Enables a Caffiene-cache backed implementation of a PreparsedDocumentProvider.                                                  |
| dgs.graphql.preparsed-document-provider.maximum-cache-size      | Long     | `2000`                             | Sets the maximum size of the PreparsedDocumentProvider Caffiene-cache.                                                          |
| dgs.graphql.preparsed-document-provider.cache-validity-duration | String   | `PT1H`                             | How long a cached entry in the PreparsedDocumentProvider Caffiene-cache is valid for. Specified as an ISO-8601 duration string. |


#### Example: Configure the location of the GraphQL Schema Files

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

Now, if you want to add additional locations to look for the GraphQL Schema files you add them to the list.
For example, let's say we want to also look into your `graphql-experimental-schemas`:

```yaml
dgs:
  graphql:
    schema-locations:
      - classpath*:graphql-schemas/**/*.graphql*
      - classpath*:graphql-experimental-schemas/**/*.graphql*
```

### DGS Extended Scalars: graphql-dgs-extended-scalars

| Name                                              | Type    | Default | Description                                                                                                                                                                                                          |
|---------------------------------------------------| ------- | ------- |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| dgs.graphql.extensions.scalars.enabled            | Boolean | `true`  | Registered the Scalar Extensions available in [graphql-java-extended-scalars](https://github.com/graphql-java/graphql-java-extended-scalars) for the DGS Framework.                                                  |
| dgs.graphql.extensions.scalars.chars.enabled      | Boolean | `true`  | Will register the Char scalar extension.                                                                                                                                                                             |
| dgs.graphql.extensions.scalars.numbers.enabled    | Boolean | `true`  | Will register all numeric scalar extensions (PositiveInt, NegativeInt, NonPositiveInt, NonNegativeInt, PositiveFloat, NegativeFloat, NonPositiveFloat, NonNegativeFloat, Long, Short, Byte, BigDecimal, BigInteger). |
| dgs.graphql.extensions.scalars.objects.enabled    | Boolean | `true`  | Will register the Object, Json, Url, and Locale scalar extensions.                                                                                                                                                   |
| dgs.graphql.extensions.scalars.time-dates.enabled | Boolean | `true`  | Will register the DateTime, Date, Time and LocalTime scalar extensions.                                                                                                                                              |
| dgs.graphql.extensions.scalars.ids.enabled        | Boolean | `true`  | Will register the UUID scalar extension.                                                                                                                                                                             |
| dgs.graphql.extensions.scalars.country            | Boolean | `true`  | Will register the CountryCode scalar extension.                                                                                                                                                                      |
| dgs.graphql.extensions.scalars.currency           | Boolean | `true`  | Will register the Currency scalar extension.                                                                                                                                                                         |


### DGS Extended Validation: graphql-dgs-extended-validation

| Name                                      | Type    | Default | Description                                                                                                                                                                                    |
| ----------------------------------------- | ------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| dgs.graphql.extensions.validation.enabled | Boolean | `true`  | Registered the Validation Schema Directive Extensions available in [graphql-java-extended-validation](https://github.com/graphql-java/graphql-java-extended-validation) for the DGS Framework. |

### DGS Metrics: graphql-dgs-spring-boot-micrometer

| Name                                                               | Type     | Default | Description                                                                                                                     |
| ------------------------------------------------------------------ | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------- |
| management.metrics.dgs-graphql.enabled                             | Boolean  | `true`  | Enables DGS' GraphQL metrics, via micrometer.                                                                                   |
| management.metrics.dgs-graphql.instrumentation.enabled             | Boolean  | `true`  | Enables DGS' GraphQL's base instrumentation; emits `gql.query`, `gql.resolver`, and `gql.error` meters.                         |
| management.metrics.dgs-graphql.data-loader-instrumentation.enabled | Boolean  | `true`  | Enables DGS' instrumentation for DataLoader; emits `gql.dataLoader` meters.                                                     |
| management.metrics.dgs-graphql.tag-customizers.outcome.enabled     | Boolean  | `true`  | Enables DGS' GraphQL Outcome tag customizer. This adds an OUTCOME tag that is ether SUCCESS or ERROR to the emitted gql meters. |
| management.metrics.dgs-graphql.query-signature.enabled             | Boolean  | `true`  | Enables DGS' `QuerySignatureRepository`; if available metrics will be tagged with the `gql.query.sig.hash`.                     |
| management.metrics.dgs-graphql.query-signature.caching.enabled     | Boolean  | `true`  | Enables DGS' `QuerySignature` caching; if set to false the signature will always be calculated on each request.                 |
| management.metrics.dgs-graphql.tags.limiter.limit                  | Integer  | 100     | The limit that will apply for this tag. The interpretation of this limit depends on the cardinality limiter itself.             |
| management.metrics.dgs-graphql.autotime.percentiles                | [Double] | []      | DGS Micrometer Timers percentiles, e.g. `[0.95, 0.99, 0.50]`. [^1]                                                              |
| management.metrics.dgs-graphql.autotime.percentiles-histogram      | Boolean  | `false` | Enables publishing percentile histograms for the DGS Micrometer Timers. [^1]                                                    |

!!!hint
    You can configure percentiles, and enable percentile histograms, directly via the per-meter customizations available
    out of the box in Spring Boot. For example, to enable percentile histograms for all `gql.*` meters you can
    set the following property:

    ```
    management.metrics.distribution.percentiles-histogram.gql=true
    ```

    For more information please refer to [Spring Boot's Per Meter Properties].

[^1]: [Spring Boot's Per Meter Properties] can be used to configure percentiles, and histograms, out of the box.

[Spring Boot's Per Meter Properties]: https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#actuator.metrics.customizing.per-meter-properties

The DGS framework is designed to work well with tools such as JRebel.
In large Spring Boot codebases with many dependencies, it can take some time to restart the application during development.
Waiting for the application to start can be disruptive to the development workflow.

## Enabling development mode for hot reloading
Tools like JRebel allow for hot-reloading code.
You make code changes compile, and without restarting the application, see the changes in the running application.
Actively developing a DGS often includes making schema changes and wiring datafetchers.
Some initialization needs to happen to pick up such changes.
Out-of-the-box the DGS framework caches this initialization to be as efficient as possible in production, so the initialization only happens during startup.

We can configure the DGS framework to run in development mode during development, which re-initializes the schema on each request.
You can enable development mode in three ways:

1. Set the `dgs.reload` configuration property to `true` (e.g. in `application.yml`)
2. Enable the `laptop` profile
3. Implement your own `ReloadIndicator` bean to be fully in control over when to reload. This is useful when working with fully [dynamic schemas](../dynamic-schemas).

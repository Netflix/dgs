# Netflix DGS Framework Documentation

## Table of Contents
1. [Introduction](#introduction)
2. [Core Features](#core-features)
3. [Installation](#installation)
4. [Quick Start](#quick-start)
5. [Core Concepts](#core-concepts)
    - [GraphQL Schema](#graphql-schema)
    - [DataFetchers](#datafetchers)
6. [Advanced Topics](#advanced-topics)
    - [WebFlux Integration](#webflux-integration)
7. [Testing](#testing)
8. [Contributing](#contributing)
9. [License](#license)

## Introduction

The **Netflix Domain Graph Service (DGS)** framework simplifies the creation of scalable, flexible GraphQL APIs in Java. It integrates seamlessly with Spring Boot, providing essential tools for building domain-specific GraphQL services with minimal boilerplate.

## Core Features

- **Annotation-driven GraphQL API**: Simplified schema definitions using annotations.
- **Spring Boot Integration**: Out-of-the-box compatibility with Spring Boot.
- **WebFlux Support**: Reactive GraphQL services using Spring WebFlux.
- **Federation**: Easily build federated GraphQL services.

## Installation

Add the following dependency to your `pom.xml`:



```xml
<dependency>
    <groupId>com.netflix.graphql.dgs</groupId>
    <artifactId>graphql-dgs-spring-boot-starter</artifactId>
    <version>latest.version</version>
</dependency>
```


## Quick Start

1. **Create a Spring Boot Application**: Initialize a Spring Boot project.

2. **Define a GraphQL Schema**: Create a `.graphqls` file in `src/main/resources/schema/`.

    ```graphql
    type Query {
        shows: [Show]
    }

    type Show {
        title: String
        releaseYear: Int
    }
    ```

3. **Implement a DataFetcher**:

    ```java
    @DgsComponent
    public class ShowsDataFetcher {
        private final List<Show> shows = List.of(
            new Show("Stranger Things", 2016),
            new Show("The Crown", 2016)
        );

        @DgsQuery
        public List<Show> shows() {
            return shows;
        }
    }
    ```

4. **Run the Application**: Access the GraphQL endpoint at `/graphql`.

## Core Concepts

### GraphQL Schema

The schema defines the structure of your API. Place `.graphqls` files under `src/main/resources/schema/`.

### DataFetchers

DataFetchers resolve data for GraphQL queries. Annotate methods with `@DgsQuery`, `@DgsMutation`, or `@DgsData`.

## Advanced Topics

### WebFlux Integration

DGS is fully compatible with Spring WebFlux, allowing you to build reactive GraphQL services. To enable WebFlux, add the following dependency:

```xml
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-webflux</artifactId>
    </dependency>
    
```

Implement DataFetchers using reactive types such as `Mono` and `Flux`:


```java
    @DgsComponent
    public class ReactiveShowsDataFetcher {

        @DgsQuery
        public Flux<Show> shows() {
            return Flux.just(
                new Show("Stranger Things", 2016),
                new Show("The Crown", 2016)
            );
        }
    }
```

## Testing

DGS supports both unit and integration testing with Spring Boot's test framework, including reactive tests with WebFlux.

## Contributing

We welcome contributions! Please follow our [Contributing Guidelines](./CONTRIBUTING.md).

## License

Licensed under the Apache License 2.0. See the [LICENSE](./LICENSE) file for details.


## What is a DGS (Domain Graph Service)?

A [Domain Graph Service] (DGS) is an individual service that contributes to a [federated]  [GraphQL] schema.
A [DGS] typically owns a single [entity] and its schema.
A stand-alone GraphQL service is not a DGS for the purposes of this definition, but for the most part you _can_ use the frameworks discussed in this manual to create stand-alone GraphQL services as well.

Keep in mind that each DGS _must_ act as a standalone GraphQL server, meaning the SDL must define a top level `type Query @extends {}` definition with at least one field defined in it. This particular rule is imposed by the [graphql-java](https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/schema/idl/SchemaGenerator.java#L317) library that the schema registry uses to instantiate an executable schema based off of the IDL.

## What is the DGS framework?

The DGS framework is a custom framework developed by the devex team to provide an out of the box, easy to use GraphQL solution at Netflix. 

It can be used in conjunction with [federation](../../federation/what-is-federation.md), or by itself, as an easy to use GraphQL server implementation.

!!!info "Spring Boot is the paved path for Domain Graph Services"
    DGSs are based on [Spring Boot], which is the [paved path] for services within Netflix. 
    Other technology stacks are currently not supported.
    Although good GraphQL support exists for runtimes such as [Node.js], these technologies are not (yet) well-supported within the Netflix ecosystem, and therefore not supported by the Gateway and GraphQL Devex team.
    
## Other Tools for DGSes

* [**Reggie**](../reggie/index.md): a custom UI that helps DGSes register their endpoints and available, compare schema versions, view entity usage and more.
* [**DGS Gradle Plugin**](../gradle-plugin.md): A Gradle plugin that allows DGSes to validate and push their schemas. 

## Project Information

The Slack channel for discussion and support for the [DGS] framework is [#studio-edge-devex].
The source code can be found on [Stash](https://stash.corp.netflix.com/projects/PX/repos/domain-graph-service-java/browse).

--8<-- "docs/reference_links"

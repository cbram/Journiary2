import { Resolver, Query } from 'type-graphql';

@Resolver()
export class HelloWorldResolver {
    @Query(() => String)
    hello(): string {
        return "Hello World!";
    }
} 
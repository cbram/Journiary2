import { ObjectType, Field, ID, Int } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, OneToMany, ManyToOne } from "typeorm";
import { Tag } from "./Tag";
import { User } from "./User";

@ObjectType({ description: "Represents a category for grouping tags" })
@Entity()
export class TagCategory {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field()
    @Column({ unique: true })
    name!: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    displayName?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    emoji?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    color?: string;

    @Field()
    @Column({ default: false })
    isSystemCategory!: boolean;

    @Field(() => Int)
    @Column({ default: 0 })
    sortOrder!: number;

    @Field()
    @Column({ default: true })
    isExpanded!: boolean;

    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @ManyToOne(() => User, user => user.createdTagCategories)
    creator!: User;

    @Field(() => [Tag])
    @OneToMany(() => Tag, tag => tag.category)
    tags!: Tag[];
} 
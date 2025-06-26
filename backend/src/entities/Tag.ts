import { ObjectType, Field, ID, Int } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToMany, JoinTable, ManyToOne } from "typeorm";
import { Memory } from "./Memory";
import { TagCategory } from "./TagCategory";

@ObjectType({ description: "Represents a tag for categorizing memories" })
@Entity()
export class Tag {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field()
    @Column({ unique: true })
    name!: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    normalizedName?: string;

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
    isSystemTag!: boolean;

    @Field(() => Int)
    @Column({ default: 0 })
    usageCount!: number;

    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @Field({ nullable: true })
    @Column({ type: "timestamp", nullable: true })
    lastUsedAt?: Date;

    @Field()
    @Column({ default: false })
    isArchived!: boolean;

    @Field(() => Int)
    @Column({ default: 0 })
    sortOrder!: number;

    @Field(() => TagCategory, { nullable: true })
    @ManyToOne(() => TagCategory, category => category.tags, { nullable: true })
    category?: TagCategory;

    @Field(() => ID, { nullable: true })
    @Column({ nullable: true })
    categoryId?: string;

    @Field(() => [Memory])
    @ManyToMany(() => Memory, memory => memory.tags)
    memories!: Memory[];

    // Self-referencing relationship for related tags
    @Field(() => [Tag])
    @ManyToMany(() => Tag)
    @JoinTable()
    relatedTags!: Tag[];
} 
import { ObjectType, Field, ID, Int } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, ManyToMany, JoinTable, CreateDateColumn, UpdateDateColumn } from "typeorm";
import { TagCategory } from "./TagCategory";
import { Memory } from "./Memory";
import { User } from "./User";

@ObjectType({ description: "A tag to categorize memories" })
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
    @UpdateDateColumn({ nullable: true })
    lastUsedAt?: Date;

    @Field()
    @Column({ default: false })
    isArchived!: boolean;

    @Field(() => Int)
    @Column({ default: 0 })
    sortOrder!: number;

    @Field({ nullable: true })
    @Column({ nullable: true })
    tagDescription?: string;

    @ManyToOne(() => User, user => user.createdTags)
    creator!: User;

    @ManyToOne(() => TagCategory, category => category.tags, { nullable: true, onDelete: 'SET NULL' })
    @Field(() => TagCategory, { nullable: true })
    category?: TagCategory | null;

    @ManyToMany(() => Memory, memory => memory.tags)
    memories!: Memory[];

    @Field(() => [Tag], { nullable: true })
    @ManyToMany(() => Tag)
    @JoinTable({
        name: "tag_related_tags",
        joinColumn: { name: "tag_id", referencedColumnName: "id" },
        inverseJoinColumn: { name: "related_tag_id", referencedColumnName: "id" }
    })
    relatedTags?: Tag[];
} 
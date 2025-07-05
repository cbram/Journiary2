import { Entity, PrimaryColumn, Column, CreateDateColumn, Index } from "typeorm";

@Entity()
export class DeletionLog {
    @PrimaryColumn()
    entityId!: string;

    @PrimaryColumn()
    entityType!: string;

    @Index()
    @CreateDateColumn()
    deletedAt!: Date;

    @Column({ nullable: true })
    @Index()
    tripId?: string;

    @Column({ nullable: true })
    @Index()
    ownerId?: string;
} 
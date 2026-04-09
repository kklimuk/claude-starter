#!/usr/bin/env bun
/**
 * Drop per-worktree Postgres databases that no longer have a matching git worktree.
 *
 * Convention: each worktree gets its own database named `{{db_prefix}}_<worktree-name>`,
 * created by the post-checkout hook. When you remove a worktree, this script cleans up
 * the orphaned database.
 *
 * Usage: bun scripts/db-cleanup.ts
 */

import { $ } from "bun";

const worktrees = await $`git worktree list --porcelain`.text();
const worktreeNames = new Set(
	worktrees
		.split("\n")
		.filter((l) => l.startsWith("worktree "))
		.map((l) => l.replace("worktree ", "").split("/").pop() ?? ""),
);

const result = await Bun.sql`
	SELECT datname FROM pg_database
	WHERE datname LIKE '{{db_prefix}}_%' AND datname != '{{db_prefix}}_dev'
`;
const databases: string[] = result.map((r: { datname: string }) => r.datname);

const orphaned = databases.filter((db) => {
	const wtName = db.replace("{{db_prefix}}_", "").replaceAll("_", "-");
	return !worktreeNames.has(wtName);
});

if (orphaned.length === 0) {
	console.log("No orphaned databases found.");
	process.exit(0);
}

console.log("Orphaned databases (no matching worktree):");
for (const db of orphaned) {
	console.log(`  - ${db}`);
}

process.stdout.write("\nDrop these databases? [y/N] ");
for await (const line of console) {
	if (line.trim().toLowerCase() === "y") {
		for (const db of orphaned) {
			try {
				await $`DATABASE_URL=postgres://localhost:5432/${db} bun bake db drop`;
				console.log(`Dropped ${db}`);
			} catch {
				console.log(`Failed to drop ${db}`);
			}
		}
	} else {
		console.log("Aborted.");
	}
	break;
}

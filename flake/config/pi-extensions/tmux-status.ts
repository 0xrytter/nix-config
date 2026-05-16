/**
 * Hides the pi footer and writes session state to /tmp for the tmux statusline.
 * The tmux ai-status.py script reads /tmp/pi-status-<pid>.json.
 * Session costs accumulate in ~/.pi/sessions/. Rate log in ~/.pi/rate-log.json.
 */

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { basename, join } from "node:path";
import { tmpdir, homedir } from "node:os";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STATE_FILE   = join(tmpdir(), `pi-status-${process.pid}.json`);
const PI_DIR       = join(homedir(), ".pi");
const SESSIONS_DIR = join(PI_DIR, "sessions");
const RATE_LOG     = join(PI_DIR, "rate-log.json");
const CAPS_FILE    = join(homedir(), ".claude", "caps.json");
const LLM_MARKER   = ".llmthing-sessions";
const LLM_LOG_DIR  = join(homedir(), "Projects", "thinglaunch", "llmthing", "logs");

let cachedLlmLogDir: string | null | undefined;
let cachedPiSessionFile: string | undefined;
let cachedPiLogFile: string | undefined;

function ensureDirs(): void {
	try { mkdirSync(SESSIONS_DIR, { recursive: true }); } catch {}
}

function loadCaps(): Record<string, any> {
	try { return JSON.parse(readFileSync(CAPS_FILE, "utf8")); } catch { return {}; }
}

function getRateLimit(modelId: string, caps: Record<string, any>): { messages: number; window_hours: number } | null {
	for (const [prefix, cap] of Object.entries(caps)) {
		if (prefix.startsWith("_")) continue;
		if (modelId.toLowerCase().startsWith(prefix.toLowerCase())) {
			return cap as { messages: number; window_hours: number };
		}
	}
	return null;
}

function updateRateLog(modelId: string, caps: Record<string, any>): object | null {
	const cap = getRateLimit(modelId, caps);
	if (!cap) return null;

	const windowMs = cap.window_hours * 3600 * 1000;
	const now = Date.now();

	let log: number[] = [];
	try { log = JSON.parse(readFileSync(RATE_LOG, "utf8")); } catch {}

	log = log.filter(ts => now - ts < windowMs);
	log.push(now);
	try { writeFileSync(RATE_LOG, JSON.stringify(log)); } catch {}

	return {
		used:         log.length,
		limit:        cap.messages,
		window_hours: cap.window_hours,
		resets_at:    log[0] + windowMs,
	};
}

function writeSessionCost(sessCost: number): void {
	const today = new Date().toISOString().slice(0, 10);
	try {
		writeFileSync(
			join(SESSIONS_DIR, `${process.pid}.json`),
			JSON.stringify({ pid: process.pid, started_date: today, sess_cost: sessCost })
		);
	} catch {}
}

function findLlmLogDir(root: string, depth = 0): string | null {
	if (depth > 7) return null;
	try {
		if (existsSync(join(root, LLM_MARKER))) return root;
		for (const entry of readdirSync(root, { withFileTypes: true })) {
			if (!entry.isDirectory()) continue;
			const skip = [".git", "node_modules", ".cache", ".npm", ".local", ".mozilla", ".pi", ".claude"];
			if (skip.includes(entry.name)) continue;
			const found = findLlmLogDir(join(root, entry.name), depth + 1);
			if (found) return found;
		}
	} catch {}
	return null;
}

function getLlmLogDir(): string | null {
	if (cachedLlmLogDir !== undefined) return cachedLlmLogDir;
	const envDir = process.env.LLMTHING_LOG_DIR;
	if (envDir && existsSync(envDir)) return (cachedLlmLogDir = envDir);
	if (existsSync(join(LLM_LOG_DIR, LLM_MARKER))) return (cachedLlmLogDir = LLM_LOG_DIR);
	cachedLlmLogDir = findLlmLogDir(join(homedir(), "Projects"));
	return cachedLlmLogDir;
}

function textFromContent(content: any): string {
	if (typeof content === "string") return content.trim();
	if (!Array.isArray(content)) return "";
	return content
		.map((block) => block?.type === "text" ? block.text || "" : "")
		.filter((s) => s.trim())
		.join("\n")
		.trim();
}

function projectSlug(cwd: string): string {
	return cwd.replace(/^\/+/, "").replace(/\/+$/g, "").replace(/\//g, "-") || "unknown";
}

function yamlSafe(value: string): string {
	return value.replace(/\s+/g, " ").replace(/:/g, " -").trim();
}

function pad(n: number): string {
	return String(n).padStart(2, "0");
}

function localDate(d: Date): string {
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function localTimestamp(d: Date): string {
	return `${localDate(d)}-${pad(d.getHours())}${pad(d.getMinutes())}`;
}

function timestampFromSessionFile(sessionFile: string | undefined): string {
	if (sessionFile) {
		const stem = basename(sessionFile, ".jsonl");
		const raw = stem.split("_")[0]; // Pi uses UTC, e.g. 2026-05-16T15-49-03-610Z
		const m = raw.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})-(\d{3})Z$/);
		if (m) {
			const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6], +m[7]));
			return localTimestamp(d);
		}
	}
	return localTimestamp(new Date());
}

function sessionIdFromFile(sessionFile: string | undefined, ctx: any): string {
	if (sessionFile) {
		const id = basename(sessionFile, ".jsonl").split("_")[1];
		if (id) return id;
	}
	try { return ctx.sessionManager.getSessionId?.() || "unknown"; } catch {}
	return "unknown";
}

function llmOutputPath(logDir: string, sessionFile: string | undefined, sessionId: string): string {
	if (cachedPiSessionFile === sessionFile && cachedPiLogFile) return cachedPiLogFile;

	const ts = timestampFromSessionFile(sessionFile);
	const base = join(logDir, `session-${ts}.md`);
	if (!existsSync(base)) {
		cachedPiSessionFile = sessionFile;
		cachedPiLogFile = base;
		return base;
	}

	try {
		if (readFileSync(base, "utf8").includes(`session_id: ${sessionId}`)) {
			cachedPiSessionFile = sessionFile;
			cachedPiLogFile = base;
			return base;
		}
	} catch {}

	const suffixed = join(logDir, `session-${ts}-${sessionId.slice(0, 8)}.md`);
	cachedPiSessionFile = sessionFile;
	cachedPiLogFile = suffixed;
	return suffixed;
}

function writeLlmthingLog(ctx: any): void {
	try {
		const logDir = getLlmLogDir();
		if (!logDir) return;
		mkdirSync(logDir, { recursive: true });

		const turns: Array<["U" | "A", string]> = [];
		let model = ctx.model?.id || "unknown";

		for (const e of ctx.sessionManager.getBranch()) {
			if (e.type === "model_change" && e.modelId) model = e.modelId;
			if (e.type !== "message") continue;
			const role = e.message?.role;
			if (role !== "user" && role !== "assistant") continue;
			const text = textFromContent(e.message?.content);
			if (!text) continue;
			turns.push([role === "user" ? "U" : "A", text]);
			if (role === "assistant" && e.message?.model) model = e.message.model;
		}

		if (!turns.length) return;

		const sessionFile = ctx.sessionManager.getSessionFile?.();
		const sessionId = sessionIdFromFile(sessionFile, ctx);
		const cwd = ctx.sessionManager.getCwd?.() || ctx.sessionManager.getHeader?.()?.cwd || process.cwd();
		const date = localDate(new Date());
		const summary = yamlSafe(turns[0][1].slice(0, 120)) || `pi session ${timestampFromSessionFile(sessionFile)}`;
		const body = turns.map(([role, text]) => `${role}: ${text}`).join("\n\n");

		writeFileSync(
			llmOutputPath(logDir, sessionFile, sessionId),
			`---\n` +
			`summary: ${summary}\n` +
			`date: ${date}\n` +
			`agent: pi\n` +
			`model: ${model}\n` +
			`project: ${projectSlug(cwd)}\n` +
			`session_id: ${sessionId}\n` +
			`---\n\n` +
			`${body}\n`,
		);
	} catch {}
}

function writeState(ctx: any, rate: object | null): void {
	try {
		let sessCost = 0, sessInput = 0, sessOutput = 0, humanMsgs = 0, toolOps = 0;

		for (const e of ctx.sessionManager.getBranch()) {
			if (e.type !== "message") continue;
			if (e.message.role === "assistant") {
				const m = e.message as AssistantMessage;
				sessCost   += m.usage.cost.total;
				sessInput  += m.usage.input;
				sessOutput += m.usage.output;
				const content = (m as any).content;
				if (Array.isArray(content)) {
					toolOps += content.filter((c: any) => c.type === "tool_use" || c.type === "toolCall").length;
				}
			} else if (e.message.role === "user") {
				humanMsgs++;
			}
		}

		const ctxUsage = ctx.getContextUsage?.();

		let hasThinking = false;
		for (const e of ctx.sessionManager.getBranch()) {
			if (e.type !== "message" || e.message?.role !== "assistant") continue;
			const c = (e.message as any).content;
			if (Array.isArray(c) && c.some((b: any) => b.type === "thinking")) {
				hasThinking = true;
				break;
			}
		}

		writeSessionCost(sessCost);

		writeFileSync(STATE_FILE, JSON.stringify({
			pid:            process.pid,
			model:          ctx.model?.id ?? "unknown",
			thinking:       hasThinking ? "extended" : "",
			ctx_pct:        ctxUsage?.percent ?? ctxUsage?.used_percentage ?? 0,
			sess_cost:      sessCost,
			sess_input:     sessInput,
			sess_output:    sessOutput,
			human_messages: humanMsgs,
			tool_ops:       toolOps,
			rate,
		}));
	} catch {}
}

export default function (pi: ExtensionAPI) {
	ensureDirs();
	const caps = loadCaps();

	pi.on("session_start", async (_event, ctx) => {
		writeState(ctx, null);
		ctx.ui.setFooter((_tui, _theme, _footerData) => ({
			dispose:    () => {},
			invalidate: () => {},
			render:     (_width: number) => [],
		}));
	});

	pi.on("turn_end", async (_event, ctx) => {
		const model = ctx.model?.id ?? "unknown";
		const rate = updateRateLog(model, caps);
		writeState(ctx, rate);
		writeLlmthingLog(ctx);

		const child = spawn("python3", [
			join(homedir(), ".config", "tmux", "ai-status.py"),
			"write-pi", String(process.pid),
		], { detached: true, stdio: "ignore" });
		child.unref();
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		writeLlmthingLog(ctx);
	});
}

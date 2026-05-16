/**
 * Hides the pi footer and writes session state to a shared status dir for tmux.
 * Containerized pi is keyed by TMUX_AI_PANE so host tmux can read it.
 * Session costs accumulate in ~/.pi/sessions/. Rate log in ~/.pi/rate-log.json.
 */

import { writeFileSync, readFileSync, mkdirSync } from "node:fs";
import { spawn } from "node:child_process";
import { join } from "node:path";
import { tmpdir, homedir } from "node:os";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STATUS_DIR   = process.env.TMUX_AI_STATUS_DIR || tmpdir();
const PANE_ID      = (process.env.TMUX_AI_PANE || "").replace(/%/g, "");
const STATE_ID     = PANE_ID || String(process.pid);
const STATE_FILE   = join(STATUS_DIR, `pi-status-${STATE_ID}.json`);
const PI_DIR       = join(homedir(), ".pi");
const SESSIONS_DIR = join(PI_DIR, "sessions");
const RATE_LOG     = join(PI_DIR, "rate-log.json");
const CAPS_FILE    = join(homedir(), ".claude", "caps.json");

function ensureDirs(): void {
	try { mkdirSync(SESSIONS_DIR, { recursive: true }); } catch {}
	try { mkdirSync(STATUS_DIR, { recursive: true }); } catch {}
	if (PANE_ID) {
		try { writeFileSync(join(STATUS_DIR, `pane-${PANE_ID}.kind`), "pi"); } catch {}
	}
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
			pane:           PANE_ID,
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

		const child = spawn("python3", [
			join(homedir(), ".config", "tmux", "ai-status.py"),
			"write-pi", STATE_ID,
		], { detached: true, stdio: "ignore" });
		child.unref();
	});
}

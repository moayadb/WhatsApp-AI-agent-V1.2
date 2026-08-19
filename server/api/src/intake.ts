import { env } from './env';
import { chatJson, llmConfigured, LlmUnavailable, type ChatMessage } from './llm';
import { logger } from './logger';

/**
 * Journey step 2 — the intake interview, run by a model.
 *
 * The point is not to collect answers into fields. It is to end up with a
 * monitoring prompt written for THIS business: the manager describes what he
 * sells, what goes wrong, and what he wants to be dragged into, and the model
 * turns that into the instructions the analysis agent will follow. That
 * generated prompt is shown back to him, because a manager who cannot see what
 * the system was told will not trust what it flags.
 */

export interface IntakeTurn {
  role: 'assistant' | 'user';
  text: string;
}

export interface IntakeResult {
  reply: string;
  done: boolean;
  /** Filled only on the final turn. */
  generatedPrompt: string | null;
  /** Thresholds the model inferred from the conversation. */
  thresholds: {
    first_response_minutes?: number;
    cold_lead_hours?: number;
    detect_unauthorized_promise?: boolean;
    detect_off_channel?: boolean;
  };
  source: 'llm' | 'script';
}

const LANGUAGE_NAME: Record<string, string> = {
  ar: 'Arabic',
  en: 'English',
};

function systemPrompt(locale: string): string {
  const language = LANGUAGE_NAME[locale] ?? 'Arabic';
  return `You are onboarding a business owner or sales manager onto a system that
watches their team's WhatsApp conversations with clients and alerts the manager
only when they personally need to step in.

LANGUAGE
Mirror the manager: always answer in the language their own messages are
written in, whatever it is. Never assume a language from context or names. If
their language is genuinely ambiguous (numbers only, emoji), fall back to
${language}, the language their app is set to. The generated prompt at the end
must also be written in the language the manager actually used.

YOUR JOB
Interview them until you genuinely understand their business, then write the
monitoring prompt the analysis agent will use for them specifically.

Ask about, in your own words and adapting to what they tell you:
  - what the business does and what clients typically contact them about
  - how the team is organised and who talks to clients
  - what has actually gone wrong recently — a lost client, a complaint, a deal
    that died
  - what they want to be interrupted for, and just as importantly what they do
    NOT want to be interrupted for
  - how fast a new client should get a first reply

RULES
- Ask ONE question at a time. Never a numbered list of questions.
- Build on what they just said. If an answer is vague or interesting, follow up
  on it rather than moving to the next topic.
- Keep going until you could write a comprehensive monitoring prompt — usually
  five to eight exchanges. Do not finish before you understand: the business and
  what it sells, how the team works, at least one real failure, what to alert on
  AND what to ignore, what makes a client high-value, and the response time.
- Never invent facts they did not tell you.
- Reply in the language the manager writes in, per LANGUAGE above.

THRESHOLD RULES
- "thresholds" may only contain numbers the manager EXPLICITLY stated as the
  limit they want. Never derive a threshold from a story about a past failure.
- If the manager has not clearly given a first-response time in minutes, ask
  for it directly before finishing.

WHEN YOU HAVE ENOUGH
Set "done": true and write "generated_prompt".

The generated prompt is instructions addressed to an AI agent that will read one
WhatsApp conversation at a time between a staff member and a client. It must be
COMPREHENSIVE — this is the entire brain of the monitoring system — and follow
this structure, with clear section headings, in the manager's language:

1. BUSINESS CONTEXT — what the company sells, who its clients are, how the
   team talks to them. Two or three sentences.
2. ALERT RULES — a numbered list. Each rule states the situation concretely in
   this business's own vocabulary, with an example phrasing a client or staff
   member might actually use. Cover at minimum, dropping only what the manager
   explicitly excluded:
   - client-side risk: anger, disappointment, threats to leave or to complain
     publicly or to authorities, refund/cancellation demands, repeated unanswered
     questions
   - staff conduct: promises the company may not honour (prices, discounts,
     guaranteed returns, delivery/handover dates), moving the client to a
     personal number or another app, requesting payment privately, rudeness,
     sharing wrong information
   - the specific failures and worries the manager described, as their own rules
   - opportunity signals, if the manager wants them: clear buying intent, a
     high-value or VIP client appearing, a deal about to close
3. DO NOT ALERT — explicit list of what to stay silent about, from what the
   manager said plus routine noise (greetings, ordinary questions, normal
   negotiation).
4. SEVERITY MAP — which rules are urgent, high, medium, low, following the
   manager's priorities.

Each rule must be concrete enough that two different readers would flag the
same messages. The manager will read this prompt — make it something he
recognises as his own business, not a generic template.

RESPOND ONLY WITH JSON:
{
  "reply": "what you say to them now, in the manager's language",
  "done": false,
  "generated_prompt": null,
  "thresholds": {}
}

The example shows an EMPTY thresholds object ON PURPOSE: add first_response_minutes or cold_lead_hours ONLY with a number the manager explicitly stated in this conversation — never copy example values, never infer from stories. And never set done: true before you have explicitly asked how fast the first reply must be. On the final turn "reply" should be a
short closing line, in the manager's language, telling them the prompt below is what the
system will use and that they can change it later.`;
}

interface RawIntake {
  reply?: string;
  done?: boolean;
  generated_prompt?: string | null;
  thresholds?: IntakeResult['thresholds'];
}

/**
 * The opening question, before the manager has said anything.
 *
 * Hardcoded rather than generated so the first screen paints instantly and
 * costs nothing — and so onboarding still starts if the model is down.
 */
export function openingQuestion(locale: string): string {
  // Bilingual on purpose: the customer's language is DETECTED from their
  // reply, not assumed from the UI. The opening invites an answer in either
  // language; from the first reply onward the interviewer mirrors whatever
  // the manager writes in. The UI locale only decides which line goes first.
  const en =
    'To set this up properly I need to understand your business. What do you do, and what do clients usually message you about?';
  const ar =
    'حتى أضبط النظام على عملك، أحتاج أن أفهم طبيعته: ما مجال عملكم، وعادةً ما الذي يراسلكم العملاء بخصوصه؟';
  return locale === 'en' ? `${en}\n\n${ar}` : `${ar}\n\n${en}`;
}

/** Scripted fallback, used when no model is configured or the call fails. */
const FALLBACK: Record<string, string[]> = {
  ar: [
    'كم شخص عندك بيتواصل مع العملاء عبر واتساب؟',
    'حدّثني عن آخر عميل أو صفقة خسرتها — شو صار بالضبط؟',
    'شو الأشياء اللي بدك النظام يزعجك فيها، وشو الأشياء اللي ما بدك تنشغل فيها؟',
    'آخر سؤال: كم دقيقة كحد أقصى لازم ينتظر العميل الجديد قبل ما حدا يرد عليه؟',
  ],
  en: [
    'How many people on your team talk to clients over WhatsApp?',
    'Tell me about the last client or deal you lost — what actually happened?',
    'What do you want to be interrupted for, and what should the system stay quiet about?',
    'Last one: at most how many minutes should a new client wait before someone replies?',
  ],
};

function fallbackPrompt(locale: string, transcript: IntakeTurn[]): string {
  const answers = transcript
    .filter((t) => t.role === 'user')
    .map((t) => `- ${t.text}`)
    .join('\n');

  return locale === 'en'
    ? `You review WhatsApp conversations between staff and clients for this business.

What the manager told us:
${answers}

Alert the manager when: a client is waiting for a reply beyond the agreed time;
a conversation has gone silent while still live; a staff member promises
something the company may not honour (prices, discounts, delivery or handover
dates, guaranteed returns); a staff member moves the client off the company
channel or asks for payment privately; or a client is angry, threatening to
leave, or asking for a manager.

Do not alert on ordinary questions, normal negotiation, or slow replies outside
working hours.

Severity: urgent when money or the client is leaving today; high when it must be
handled today; medium within the week; low for awareness only.`
    : `أنت تراجع محادثات واتساب بين الموظفين والعملاء في هذا العمل.

ما ذكره المدير:
${answers}

نبّه المدير عندما: ينتظر عميل ردًا أطول من الوقت المتفق عليه؛ أو تسكت محادثة
ما زالت قائمة؛ أو يَعِد موظف بشيء قد لا تستطيع الشركة الوفاء به (أسعار، خصومات،
مواعيد تسليم، عوائد مضمونة)؛ أو ينقل موظف العميل خارج قناة الشركة أو يطلب دفعة
بشكل خاص؛ أو يكون العميل غاضبًا أو مهددًا بالمغادرة أو يطلب مديرًا.

لا تنبّه على الأسئلة الاعتيادية أو التفاوض الطبيعي أو تأخر الرد خارج ساعات العمل.

الأولوية: عاجل إذا كان المال أو العميل على وشك الضياع اليوم؛ مرتفع إذا لزم
التعامل معه اليوم؛ متوسط خلال الأسبوع؛ منخفض للعلم فقط.`;
}

function scriptedTurn(locale: string, transcript: IntakeTurn[]): IntakeResult {
  const script = FALLBACK[locale] ?? FALLBACK.ar;
  const answered = transcript.filter((t) => t.role === 'user').length;

  // The opening question is index -1; answer N leads to script[N-1].
  const next = script[answered - 1];
  if (next) {
    return {
      reply: next,
      done: false,
      generatedPrompt: null,
      thresholds: {},
      source: 'script',
    };
  }

  const minutes = extractMinutes(transcript.at(-1)?.text ?? '');
  return {
    reply: locale === 'en'
      ? 'Thanks — that is everything I need. Here is what the system will use; you can change it later in Settings.'
      : 'شكرًا، هذا كل ما احتجته. هذا ما سيعتمده النظام، ويمكنك تعديله لاحقًا من الإعدادات.',
    done: true,
    generatedPrompt: fallbackPrompt(locale, transcript),
    thresholds: minutes ? { first_response_minutes: minutes } : {},
    source: 'script',
  };
}

function extractMinutes(text: string): number | null {
  // Arabic-Indic digits map to ASCII so "١٠ دقائق" parses too.
  const normalized = text.replace(/[٠-٩]/g, (d) =>
    String(d.charCodeAt(0) - 0x0660),
  );
  const match = normalized.match(/(\d{1,4})/);
  if (!match) return null;
  const value = Number(match[1]);
  return value >= 1 && value <= 1440 ? value : null;
}

/**
 * Ask the n8n intake workflow for the next turn.
 *
 * Synchronous request/response on purpose: every call is outbound from here
 * to the public n8n instance, so it works identically from a laptop and from
 * the production box — n8n never has to reach back in.
 */
async function n8nTurn(
  transcript: IntakeTurn[],
  locale: string,
  refine?: RefineContext,
): Promise<IntakeResult> {
  const response = await fetch(env.n8nIntakeUrl, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-sanayed-secret': env.n8nSecret,
    },
    body: JSON.stringify({
      locale,
      transcript,
      mode: refine ? 'refine' : 'interview',
      current_prompt: refine?.currentPrompt ?? null,
    }),
    signal: AbortSignal.timeout(45_000),
  });
  if (!response.ok) throw new LlmUnavailable(`n8n intake ${response.status}`);

  const raw = (await response.json()) as RawIntake;
  const reply = (raw.reply ?? '').trim();
  if (!reply) throw new LlmUnavailable('n8n intake returned no reply');

  return shapeModelTurn(raw, reply, locale, transcript, refine);
}

/**
 * Refinement of an existing prompt from a chat request.
 *
 * Used both mid-conversation (right after the interview finished, while the
 * manager is still looking at the result) and any time later from Settings.
 */
export interface RefineContext {
  currentPrompt: string;
}

function refineSystemPrompt(locale: string, currentPrompt: string): string {
  const language = LANGUAGE_NAME[locale] ?? 'Arabic';
  return `A business manager already finished onboarding. Their monitoring system
runs on the prompt below, and they are asking for changes to it in chat.

CURRENT MONITORING PROMPT
---
${currentPrompt}
---

YOUR JOB
Apply what the manager asks — add rules, remove rules, change severities,
reword — and return the COMPLETE updated prompt, keeping the same section
structure (business context / alert rules / do not alert / severity map) and
everything they did not ask to change. If the request is ambiguous, ask ONE
short clarifying question instead of guessing (then done: false and
generated_prompt: null). Never invent rules they did not ask for.

LANGUAGE
Answer in the language the manager writes in; if ambiguous, ${language}. The
updated prompt stays in the language it is already written in.

RESPOND ONLY WITH JSON:
{
  "reply": "one short sentence confirming what changed, in the manager's language",
  "done": true,
  "generated_prompt": "the complete updated prompt",
  "thresholds": {}
}

Include a threshold (first_response_minutes, cold_lead_hours) ONLY if the
manager explicitly changed that number.`;
}

function shapeModelTurn(
  raw: RawIntake,
  reply: string,
  locale: string,
  transcript: IntakeTurn[],
  refine?: RefineContext,
): IntakeResult {
  const done = raw.done === true;
  let generatedPrompt: string | null = null;
  if (done) {
    // In refine mode a missing prompt means "keep the old one" — never fall
    // back to the generic template over an existing tailored prompt.
    generatedPrompt = raw.generated_prompt?.trim() || null;
    if (!generatedPrompt && !refine) {
      generatedPrompt = fallbackPrompt(locale, transcript);
    }
  }
  return {
    reply,
    done,
    generatedPrompt,
    thresholds: raw.thresholds ?? {},
    source: 'llm',
  };
}

/** Produce the next turn of the interview: n8n → direct LLM → script. */
export async function nextTurn(
  transcript: IntakeTurn[],
  locale: string,
  refine?: RefineContext,
): Promise<IntakeResult> {
  if (env.n8nIntakeUrl) {
    try {
      return await n8nTurn(transcript, locale, refine);
    } catch (error) {
      logger.warn({ err: error }, 'n8n intake unavailable; trying direct LLM');
    }
  }

  if (!llmConfigured()) {
    if (refine) {
      // Refining needs a model. Without one, leave the prompt untouched and
      // point at the manual editor rather than mangling it with a script.
      return {
        reply:
          locale === 'en'
            ? 'The AI assistant is unavailable right now — you can edit the monitoring text directly in Settings instead.'
            : 'المساعد الذكي غير متاح حاليًا — يمكنك تعديل نص المراقبة مباشرةً من الإعدادات.',
        done: false,
        generatedPrompt: null,
        thresholds: {},
        source: 'script',
      };
    }
    return scriptedTurn(locale, transcript);
  }

  const system = refine
    ? refineSystemPrompt(locale, refine.currentPrompt)
    : systemPrompt(locale);
  // Refine requests only need recent context; the interview needs all of it.
  const turns = refine ? transcript.slice(-6) : transcript;
  const messages: ChatMessage[] = [
    { role: 'system', content: system },
    ...turns.map((turn) => ({
      role: turn.role === 'assistant' ? ('assistant' as const) : ('user' as const),
      content: turn.text,
    })),
  ];

  try {
    const raw = await chatJson<RawIntake>(messages);
    const reply = (raw.reply ?? '').trim();
    if (!reply) throw new LlmUnavailable('empty reply');
    return shapeModelTurn(raw, reply, locale, transcript, refine);
  } catch (error) {
    logger.warn({ err: error }, 'intake model unavailable; using script');
    if (refine) {
      return {
        reply:
          locale === 'en'
            ? 'The AI assistant is unavailable right now — try again shortly, or edit the text directly in Settings.'
            : 'المساعد الذكي غير متاح حاليًا — حاول بعد قليل أو عدّل النص مباشرةً من الإعدادات.',
        done: false,
        generatedPrompt: null,
        thresholds: {},
        source: 'script',
      };
    }
    return scriptedTurn(locale, transcript);
  }
}

import { genkit, UserFacingError, z } from "genkit";
import {
  GenerateRequestSchema,
  GenerateResponseChunkSchema,
  GenerateResponseSchema,
  MessageSchema,
} from "genkit/model";
import { expressHandler } from "@genkit-ai/express";
import express from "express";

const ai = genkit({ model: "echoModel" });

ai.defineModel(
  {
    apiVersion: "v2",
    name: "echoModel",
  },
  async (request, { sendChunk }) => {
    for (var i = 0; i < 3; i++) {
      sendChunk({
        content: [{ text: `chunk ${i}` }],
      });
      await new Promise((r) => setTimeout(r, 1000));
    }
    return {
      message: {
        role: "model",
        content: [
          {
            text:
              "Echo: " +
              request.messages
                .map((m) => m.content.map((c) => c.text).join())
                .join(),
          },
        ],
      },
      finishReason: "stop",
    };
  }
);

const echoString = ai.defineFlow(
  { name: "echoString", inputSchema: z.string() },
  async (input) => input
);

const processObject = ai.defineFlow(
  {
    name: "processObject",
    inputSchema: z.object({
      message: z.string(),
      count: z.number(),
    }),
    outputSchema: z.object({
      reply: z.string(),
      newCount: z.number(),
    }),
  },
  async (input) => ({
    reply: "reply: " + input.message,
    newCount: input.count + 1,
  })
);

const streamObjects = ai.defineFlow(
  {
    name: "streamObjects",
    inputSchema: z.object({
      prompt: z.string(),
    }),
    outputSchema: z.object({
      text: z.string(),
      summary: z.string(),
    }),
    streamSchema: z.object({
      text: z.string(),
      summary: z.string(),
    }),
  },
  async (input, { sendChunk }) => {
    for (var i = 0; i < 5; i++) {
      sendChunk({
        text: "input: " + i,
        summary: "summary " + i,
      });
      await new Promise((r) => setTimeout(r, 1000));
    }

    return {
      text: "input: " + input.prompt,
      summary: "summary is summary",
    };
  }
);

const generate = ai.defineFlow(
  {
    name: "generate",
    inputSchema: GenerateRequestSchema,
    outputSchema: GenerateResponseSchema,
    streamSchema: GenerateResponseChunkSchema,
  },
  async (req, { sendChunk }) =>
    ai.generate({
      messages: req.messages,
      onChunk: sendChunk,
    })
);

export const streamyThrowy = ai.defineFlow(
  {
    name: "streamyThrowy",
    inputSchema: z.number(),
    outputSchema: z.string(),
    streamSchema: z.object({ count: z.number() }),
  },
  async (count, { sendChunk }) => {
    let i = 0;
    for (; i < count; i++) {
      if (i == 3) {
        throw new UserFacingError("INTERNAL", "whoops");
      }
      await new Promise((r) => setTimeout(r, 1000));
      sendChunk({ count: i });
    }
    return `done: ${count}, streamed: ${i} times`;
  }
);

export const throwy = ai.defineFlow(
  { name: "throwy", inputSchema: z.string(), outputSchema: z.string() },
  async (subject) => {
    const foo = await ai.run("call-llm", async () => {
      return `subject: ${subject}`;
    });
    if (subject) {
      throw new UserFacingError("INTERNAL", "whoops");
    }
    return await ai.run("call-llm", async () => {
      return `foo: ${foo}`;
    });
  }
);

const app = express();
app.use(express.json());

app.post("/echoString", expressHandler(echoString));
app.post("/generate", expressHandler(generate));
app.post("/processObject", expressHandler(processObject));
app.post("/streamObjects", expressHandler(streamObjects));
app.post("/throwy", expressHandler(throwy));
app.post("/streamyThrowy", expressHandler(streamyThrowy));

app.listen(8080);

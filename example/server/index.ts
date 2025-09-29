import { genkit, z } from "genkit";
import {
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
    sendChunk({
      content: [{ text: "chunk 1" }],
    });
    sendChunk({
      content: [{ text: "chunk 2" }],
    });
    sendChunk({
      content: [{ text: "chunk 3" }],
    });

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
    inputSchema: MessageSchema,
    outputSchema: GenerateResponseSchema,
    streamSchema: GenerateResponseChunkSchema,
  },
  async (input, { sendChunk }) =>
    ai.generate({
      prompt: input.content,
      onChunk: sendChunk,
    })
);

const app = express();
app.use(express.json());

app.post("/echoString", expressHandler(echoString));
app.post("/generate", expressHandler(generate));
app.post("/processObject", expressHandler(processObject));
app.post("/streamObjects", expressHandler(streamObjects));

app.listen(8080);

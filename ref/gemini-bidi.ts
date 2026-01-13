/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  GoogleGenAI,
  type FunctionDeclaration,
  type FunctionResponse,
  type LiveServerMessage,
  type Part,
  type Session,
} from '@google/genai';
import {
  GenkitError,
  Part as GenkitPart,
  MessageData,
  ToolRequestPart,
} from 'genkit';
import { bidiModel } from 'genkit/beta';
import { GenerateResponseChunkData } from 'genkit/model';
import { toGeminiTool } from '../common/converters.js';
import { GoogleAIPluginOptions } from './types.js';
import { calculateApiKey } from './utils.js';

class AsyncQueue<T> {
  private queue: T[] = [];
  private resolvers: ((value: IteratorResult<T>) => void)[] = [];
  private closed = false;
  private error: Error | null = null;

  enqueue(value: T) {
    if (this.closed) return;
    if (this.resolvers.length > 0) {
      const resolve = this.resolvers.shift()!;
      resolve({ value, done: false });
    } else {
      this.queue.push(value);
    }
  }

  close() {
    this.closed = true;
    while (this.resolvers.length > 0) {
      const resolve = this.resolvers.shift()!;
      resolve({ value: undefined as any, done: true });
    }
  }

  fail(error: Error) {
    this.error = error;
    this.closed = true;
    while (this.resolvers.length > 0) {
      const resolve = this.resolvers.shift()!;
      resolve(Promise.reject(error) as any);
    }
  }

  [Symbol.asyncIterator]() {
    return this;
  }

  async next(): Promise<IteratorResult<T>> {
    if (this.queue.length > 0) {
      return { value: this.queue.shift()!, done: false };
    }
    if (this.closed) {
      if (this.error) throw this.error;
      return { value: undefined as any, done: true };
    }
    return new Promise<IteratorResult<T>>((resolve, reject) => {
      if (this.error) reject(this.error);
      else this.resolvers.push(resolve);
    });
  }
}

const DEBUG = true;
function debugLog(...args: any[]) {
  if (DEBUG) {
    console.log('[Gemini Bidi]', ...args);
  }
}

export function defineGeminiLive(pluginOptions?: GoogleAIPluginOptions) {
  return bidiModel(
    {
      name: 'googleai/gemini-2.5-flash-native-audio-preview-12-2025',
      label: 'Gemini 2.0 Flash Exp (Live)',
      supports: {
        multiturn: true,
        media: true,
        tools: true,
        toolChoice: true,
        systemRole: true,
        output: ['text', 'json'],
      },
    },
    async function* ({ inputStream }) {
      debugLog(
        'googleai/gemini-2.5-flash-native-audio-preview-12-2025 called...'
      );
      const responseQueue = new AsyncQueue<GenerateResponseChunkData>();
      let session: Session | null = null;

      // Helper to process input stream in background
      (async () => {
        try {
          const iterator = inputStream[Symbol.asyncIterator]();

          // 1. Get the first request to initialize the session
          const firstResult = await iterator.next();
          if (firstResult.done) {
            responseQueue.close();
            return;
          }
          const firstReq = firstResult.value;

          console.log(
            ' - - - -firstReq.config',
            JSON.stringify(firstReq.config, undefined, 2)
          );

          // 2. Initialize Gemini Client
          const apiKey = calculateApiKey(
            pluginOptions?.apiKey,
            firstReq.config?.apiKey as string | undefined
          );
          if (!apiKey) {
            throw new GenkitError({
              status: 'INVALID_ARGUMENT',
              message: 'Unable to resolve api key',
            });
          }
          const client = new GoogleGenAI({
            ...pluginOptions,
            apiKey: apiKey as string,
            vertexai: false, // TODO: Support Vertex AI
          });

          // 3. Connect to Live API
          session = await client.live.connect({
            model: 'gemini-2.5-flash-native-audio-preview-12-2025', // Or extract from request if we support multiple models
            config: {
              responseModalities: firstReq.config?.responseModalities as any,
              systemInstruction: firstReq.messages
                .find((m) => m.role === 'system')
                ?.content.map((c) => c.text)
                .join('\n'),
              tools: [
                {
                  functionDeclarations: firstReq.tools?.map(
                    toGeminiTool
                  ) as FunctionDeclaration[],
                },
              ],
              generationConfig: {
                candidateCount: firstReq.candidates,
                temperature: firstReq.config?.temperature,
                topP: firstReq.config?.topP,
                topK: firstReq.config?.topK,
                maxOutputTokens: firstReq.config?.maxOutputTokens,
                speechConfig: firstReq.config?.speechConfig,
              },
              speechConfig: firstReq.config?.speechConfig,
            },
            callbacks: {
              onopen: () => {
                debugLog('Connection established');
              },
              onmessage: (msg: LiveServerMessage) => {
                debugLog('Received message:'); //, JSON.stringify(msg, null, 2));
                if (msg.serverContent) {
                  const content = msg.serverContent.modelTurn;
                  if (content) {
                    const parts: GenkitPart[] = [];
                    if (content.parts) {
                      for (const part of content.parts) {
                        if (part.text) {
                          parts.push({ text: part.text });
                        }
                        if (part.inlineData) {
                          parts.push({
                            media: {
                              url: `data:${part.inlineData.mimeType};base64,${part.inlineData.data}`,
                              contentType: part.inlineData.mimeType,
                            },
                          });
                        }
                        // TODO: Handle other part types if needed
                      }
                    }
                    if (parts.length > 0) {
                      responseQueue.enqueue({
                        content: parts,
                      });
                    }
                  }
                  if (msg.serverContent.turnComplete) {
                    // Turn complete
                  }
                }
                if (msg.toolCall) {
                  const parts: ToolRequestPart[] = (
                    msg.toolCall.functionCalls || []
                  ).map((fc) => ({
                    toolRequest: {
                      name: fc.name!,
                      ref: fc.id,
                      input: fc.args,
                    },
                  }));
                  if (parts.length > 0) {
                    responseQueue.enqueue({
                      content: parts,
                    });
                  }
                }
              },
              onclose: (e) => {
                debugLog('Connection closed', e);
                responseQueue.close();
                // Ensure session is cleaned up
                session = null;
              },
              onerror: (e) => {
                debugLog('Connection error', e);
                responseQueue.fail(new Error(e.message));
                // Ensure session is cleaned up
                session = null;
              },
            },
          });

          // 4. Send the first request content
          // Filter out system messages as they are sent in setup
          const messages = firstReq.messages.filter((m) => m.role !== 'system');
          for (const msg of messages) {
            await sendToSession(session!, msg);
          }

          // 5. Loop through remaining requests
          let result = await iterator.next();
          while (!result.done) {
            const req = result.value;
            // Assuming req contains new messages to append
            // We need to distinguish between user messages and tool responses
            // Usually GenerateRequest.messages contains the conversation.
            // But in bidi streaming, we expect the client to send *new* turns?
            // If the client sends the whole history every time, we shouldn't send it all.
            // But Genkit infrastructure might send full history.
            // BidiAction is designed for streaming new inputs.
            // So we assume `req.messages` contains *new* messages.

            for (const msg of req.messages) {
              await sendToSession(session!, msg);
            }
            result = await iterator.next();
          }

          // Input stream ended
          // session.close(); // Don't close immediately if we are waiting for response?
          // The responseQueue will close when onclose is received.
          // But if we stop sending, we should probably close the session after some time or if explicit close requested?
          // BidiModel interface: when input stream closes, we should probably close the session.
          session.close();
        } catch (e) {
          responseQueue.fail(e as Error);
          session?.close();
        }
      })();

      yield* responseQueue;
    }
  );
}

async function sendToSession(session: Session, msg: MessageData) {
  if (msg.role === 'tool') {
    // Tool response
    const functionResponses: FunctionResponse[] = msg.content
      .filter((p) => p.toolResponse)
      .map((p) => ({
        name: p.toolResponse!.name,
        id: p.toolResponse!.ref,
        response: { result: p.toolResponse!.output },
      }));

    if (functionResponses.length > 0) {
      await session.sendToolResponse({ functionResponses });
    }
  } else {
    // User or Model message (usually User in input stream)
    // Convert Genkit Part to Gemini Part
    const parts: Part[] = msg.content.map((p) => {
      if (p.text) return { text: p.text };
      if (p.media) {
        return {
          inlineData: {
            mimeType: p.media.contentType || 'application/octet-stream',
            data: p.media.url.replace(/^data:.*?;base64,/, ''), // simplistic base64 extraction
          },
        };
      }
      return {};
    });

    // Heuristic: if the message contains only media, send it as realtime input
    // This allows for lower latency for audio/video streaming
    const isRealtimeInput =
      msg.role === 'user' &&
      msg.content.every((p) => p.media) &&
      msg.content.length > 0;

    if (isRealtimeInput) {
      // For RealtimeInput, we need to send individual chunks if possible,
      // but the API expects specific structure.
      // For audio, we send mimeType and data in `media` (for unary) OR `audio` (for streaming).
      // The `sendRealtimeInput` method in @google/genai SDK takes `LiveSendRealtimeInputParameters`.
      // Which has `media`, `audio`, `video`, `text`.
      // If we use `media` (BlobImageUnion), it's for image/video usually or generic blob?
      // Let's try sending as `audio` if it is audio.
      for (const part of parts) {
        if (part.inlineData) {
          const mimeType = part.inlineData.mimeType!;
          if (mimeType.startsWith('audio/')) {
            session.sendRealtimeInput({
              audio: {
                mimeType,
                data: part.inlineData.data!,
              },
            });
          } else {
            session.sendRealtimeInput({
              media: {
                mimeType,
                data: part.inlineData.data!,
              },
            });
          }
        }
      }
      return;
    }

    await session.sendClientContent({
      turns: [
        {
          role: msg.role === 'user' ? 'user' : 'model',
          parts,
        },
      ],
      turnComplete: true,
    });
  }
}

import type { FastifyRequest } from 'fastify';

export interface Session {
  userId: string;
  orgId: string;
  role: string;
}

/**
 * The signed-in identity, taken from the verified JWT.
 *
 * Every query in this API scopes by `orgId` from here and never from the
 * request body — that is the whole tenant boundary, so it must not be
 * something a client can influence.
 */
export function sessionOf(request: FastifyRequest): Session {
  const user = request.user as {
    sub: string;
    org_id: string;
    role: string;
  };
  return { userId: user.sub, orgId: user.org_id, role: user.role };
}

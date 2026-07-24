import {z} from 'zod';
export const loginSchema = z.object({email: z.string().email(), password: z.string().min(8).max(200), rememberMe: z.boolean().default(false)});
export const forgotPasswordSchema = z.object({email: z.string().email()});
export const resetPasswordSchema = z.object({accessToken: z.string().min(20), password: z.string().min(12).max(200).regex(/[A-Z]/).regex(/[a-z]/).regex(/[0-9]/)});
export const verifyEmailSchema = z.object({email: z.string().email()});

#!/usr/bin/env bash
set -euo pipefail
need=(
 "src/features/books/BookManagement.tsx"
 "src/features/books/book-service.ts"
 "src/features/books/types.ts"
 "src/app/api/v1/books/route.ts"
 "src/app/api/v1/books/[bookId]/route.ts"
 "src/app/api/v1/books/[bookId]/sections/route.ts"
 "../../database/migrations/023_book_management.sql"
 "../../docs/architecture/BOOK_MANAGEMENT.md"
 "../../docs/adr/0009-book-management.md"
)
for f in "${need[@]}"; do test -f "$f" || { echo "Missing $f"; exit 1; }; done
grep -q 'create table if not exists public.books' ../../database/migrations/023_book_management.sql
grep -q 'create_book_with_first_edition' ../../database/migrations/023_book_management.sql
grep -q 'enable row level security' ../../database/migrations/023_book_management.sql
grep -q "requirePermission(identity,'books.create')" src/features/books/book-service.ts
grep -q 'book.created' src/app/api/v1/books/route.ts
grep -q 'book.section.created' src/app/api/v1/books/'[bookId]'/sections/route.ts
! grep -R "x-organisation-id" src/app/api/v1/books src/features/books
echo "Book Management structure verified."

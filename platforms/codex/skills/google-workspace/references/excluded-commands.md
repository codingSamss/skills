# Excluded Commands (Data Modification Risk)

The following commands are intentionally NOT exposed in the google-workspace skill to prevent accidental data loss or modification.

> Only the read-only commands explicitly listed in `SKILL.md` are allowed. Any command not listed there should be treated as excluded.

## Gmail
- `gog gmail send` - Send emails
- `gog gmail drafts create/send/delete` - Modify drafts
- `gog gmail labels create/modify` - Modify labels
- `gog gmail batch delete/modify` - Bulk operations
- `gog gmail filters create/delete` - Modify filters
- `gog gmail autoforward enable/disable` - Change forwarding
- `gog gmail forwarding add` - Add forwarding address
- `gog gmail sendas create` - Create send-as alias
- `gog gmail vacation enable/disable` - Change vacation responder
- `gog gmail delegates add/remove` - Change delegation
- `gog gmail watch start/stop/renew/serve` - Pub/Sub watch operations

## Drive
- `gog drive upload` - Upload files
- `gog drive mkdir` - Create folders
- `gog drive rename` - Rename files
- `gog drive move` - Move files
- `gog drive delete` - Delete files
- `gog drive copy` - Copy files
- `gog drive share/unshare` - Change sharing permissions
- `gog drive comments create/update/delete/reply` - Modify comments

## Docs
- `gog docs create` - Create documents
- `gog docs write` - Write/append content
- `gog docs insert` - Insert text at position
- `gog docs delete` - Delete text range
- `gog docs update` - Update document content
- `gog docs find-replace` - Find and replace

## Sheets
- `gog sheets create` - Create spreadsheets
- `gog sheets update` - Update cells
- `gog sheets append` - Append rows
- `gog sheets clear` - Clear cells
- `gog sheets format` - Format cells

## Slides
- `gog slides create` - Create presentations
- `gog slides create-from-markdown` - Create from Markdown
- `gog slides add-slide` - Add slides
- `gog slides delete-slide` - Delete slides
- `gog slides replace-slide` - Replace slide images
- `gog slides update-notes` - Update slide notes

## Calendar
- `gog calendar create` - Create events
- `gog calendar update` - Update events
- `gog calendar delete` - Delete events
- `gog calendar respond` - Respond to invitations
- `gog calendar propose-time` - Propose new time
- `gog calendar focus-time` - Create focus time
- `gog calendar out-of-office` - Create out-of-office
- `gog calendar working-location` - Set working location

## Contacts
- `gog contacts create` - Create contacts
- `gog contacts update` - Update contacts
- `gog contacts delete` - Delete contacts

## Tasks
- `gog tasks lists create` - Create task lists
- `gog tasks add` - Add tasks
- `gog tasks update` - Update tasks
- `gog tasks done` - Mark complete
- `gog tasks undo` - Mark incomplete
- `gog tasks delete` - Delete tasks
- `gog tasks clear` - Clear completed tasks

## Keep
- `gog keep create` - Create notes
- `gog keep update` - Update notes
- `gog keep delete` - Delete notes

>除上方明确列出的只读命令（list/get/search/attachment）外，任何 Keep 子命令均不暴露。

## Chat
- `gog chat spaces create` - Create chat spaces
- `gog chat messages send` - Send messages
- `gog chat dm space` - Create DM spaces
- `gog chat dm send` - Send direct messages

## Forms
- `gog forms create` - Create forms

## Apps Script
- `gog appscript create` - Create projects
- `gog appscript run` - Execute functions

## Classroom
- All `create/update/delete/add/remove` sub-commands for courses, students, teachers, coursework, materials, announcements, topics, invitations, and guardians

## Config (Write)
- `gog config set` - Set config values
- `gog config unset` - Remove config values

## Auth (Write)
- `gog auth credentials` - Store credentials (setup only)
- `gog auth add` - Add accounts (setup only)
- `gog auth remove` - Remove accounts
- `gog auth tokens delete` - Delete tokens
- `gog auth alias set/unset` - Manage aliases
- `gog auth service-account set/unset` - Manage service accounts

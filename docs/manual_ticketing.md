# External Ticketing Follow-Up

The pipeline can generate ticket stubs for findings, but external tracking systems
still require manual entry. After the run is approved:

1. Review the generated stub in `out/tickets/` (e.g., `ticket_<timestamp>.md`).
2. In your organization's external system (Jira, ServiceNow, etc.), create a new ticket.
3. Copy the contents of the stub into the ticket description.
4. Attach any relevant evidence from the `out/` and `evidence/` directories.
5. Assign the ticket to the appropriate team and track the external ticket ID for follow-up.

These steps ensure findings are properly tracked beyond the internal pipeline.

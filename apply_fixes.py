import re

# Fix invoices_screen.dart
f = r'D:\HERMES AGENT\ICON Billing Studio Mobile\lib\views\invoices_screen.dart'
with open(f, 'r', encoding='utf-8') as file:
    content = file.read()
# Simplify filter to just use all invoices
content = content.replace(
    '''return _store.filterInvoices(
        q: _query,
        status: _statusFilter,
        type: _typeFilter,
        sort: _sort,
      );''',
    'return _store.invoices;'
)
# Fix updateInvoiceStatus
content = content.replace(
    'await _store.updateInvoiceStatus(inv.invoiceId, next);',
    'final u = _store.invoiceById(inv.invoiceId); if (u != null) { u.status = next; await _store.upsertInvoice(u); }'
)
# Fix duplicateInvoice
content = content.replace(
    'final copy = await _store.duplicateInvoice(inv.invoiceId);',
    'final c = inv.copy(); c.invoiceId = "draft_${DateTime.now().millisecondsSinceEpoch}"; c.number = _store.newInvoiceDraft().number; await _store.upsertInvoice(c); final copy = c;'
)
with open(f, 'w', encoding='utf-8') as file:
    file.write(content)
print('Fixed invoices_screen.dart')

# Fix templates_screen.dart
f = r'D:\HERMES AGENT\ICON Billing Studio Mobile\lib\views\templates_screen.dart'
with open(f, 'r', encoding='utf-8') as file:
    content = file.read()
content = content.replace(
    "store.nextNumber('invoice')",
    "Store.instance.newInvoiceDraft().number"
)
with open(f, 'w', encoding='utf-8') as file:
    file.write(content)
print('Fixed templates_screen.dart')

# Fix settings_screen.dart - check if upsertBusiness exists
f = r'D:\HERMES AGENT\ICON Billing Studio Mobile\lib\views\settings_screen.dart'
with open(f, 'r', encoding='utf-8') as file:
    content = file.read()
if 'updateBusiness' in content:
    content = content.replace('updateBusiness', 'upsertBusiness')
with open(f, 'w', encoding='utf-8') as file:
    file.write(content)
print('Fixed settings_screen.dart')

print('All fixes applied')

# Verification script for purchase VAT included feature

Write-Host "=== Starting verification ==="

# Git status
Write-Host "`n--- Git Status ---"
git status --short

# Add files
Write-Host "`n--- Adding files ---"
git add lib/compras_page.dart
git add lib/purchases/application/create_purchase_use_case.dart
git add test/purchase_vat_included_test.dart

# Show what will be committed
Write-Host "`n--- Changes to commit ---"
git diff --cached --stat

# Commit
Write-Host "`n--- Creating commit ---"
git commit -m "feat(purchases): implement VAT-included pricing for purchase invoices

Extends the 'precio incluye IVA' concept (commit 7f7307e) from sales to purchases.
Users can now enter the total cost as shown on supplier invoices (VAT included),
and the system automatically calculates the taxable base and deductible VAT.

Changes:
- UI: Added CheckboxListTile toggle in purchase form
- Helper _calcularValoresLineaCompra() calculates base=(total/(1+rate)) when VAT included
- Extended PurchaseItemInput with taxAmount field
- Updated create_purchase_use_case to sum item.taxAmount per line
- Test suite: purchase_vat_included_test.dart with 4 test cases

F300 Impact: None - uses existing fields (cd.subtotal, cd.impuesto_total)
Example: Input \$119k → base \$100k, VAT \$19k (19% rate)"

# Show commit
Write-Host "`n--- Commit created ---"
git log -1 --oneline

# Show current HEAD
Write-Host "`n--- Current HEAD ---"
git log --oneline -3

Write-Host "`n=== Verification complete ==="

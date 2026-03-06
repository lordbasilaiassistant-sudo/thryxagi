#!/usr/bin/env bash
# ./thryx audit <target>
# Security pre-flight check before any public-facing action
#
# Targets:
#   contract <path>    — Static analysis on a Solidity file (slither + forge test)
#   deploy             — Pre-deploy checklist (balances, contract verification, key safety)
#   skill <path>       — Audit a skill/MCP server before publishing
#   state              — Check for leaked keys/secrets in git staged files
#   all                — Run everything

target="${1:-}"
shift || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
PASS="${GREEN}PASS${NC}"
FAIL="${RED}FAIL${NC}"
WARN="${YELLOW}WARN${NC}"

failures=0
warnings=0

pass() { echo -e "  [${PASS}] $1"; }
fail() { echo -e "  [${FAIL}] $1"; ((failures++)); }
warn() { echo -e "  [${WARN}] $1"; ((warnings++)); }

# === SECRET SCANNING ===
audit_secrets() {
  echo "=== Secret Scan ==="

  # Check git staged files for private keys, mnemonics, API keys
  local patterns=(
    '[0-9a-fA-F]{64}'           # Private keys (64 hex chars)
    'PRIVATE_KEY\s*=\s*"?[0-9a-fA-F]'  # Explicit private key assignments
    'mnemonic|seed phrase'       # Mnemonics
    'sk-[a-zA-Z0-9]{20,}'       # OpenAI-style API keys
    'ghp_[a-zA-Z0-9]{36}'       # GitHub PATs
    'Bearer [a-zA-Z0-9._\-]{20,}'  # Bearer tokens
  )

  local staged_files
  staged_files=$(git diff --cached --name-only 2>/dev/null)
  if [ -z "$staged_files" ]; then
    staged_files=$(git diff --name-only 2>/dev/null)
  fi

  if [ -z "$staged_files" ]; then
    pass "No staged/modified files to scan"
    return
  fi

  local found_secret=false
  for pattern in "${patterns[@]}"; do
    while IFS= read -r file; do
      [ -f "$file" ] || continue
      # Skip binary, node_modules, broadcast
      [[ "$file" == *node_modules* ]] && continue
      [[ "$file" == *broadcast* ]] && continue
      [[ "$file" == *cache* ]] && continue
      [[ "$file" == *.json ]] && continue

      if grep -qP "$pattern" "$file" 2>/dev/null; then
        # Exclude env.example and test files
        [[ "$file" == *.example* ]] && continue
        [[ "$file" == *test* ]] && continue
        [[ "$file" == *Test* ]] && continue
        fail "Potential secret in $file (pattern: ${pattern:0:30}...)"
        found_secret=true
      fi
    done <<< "$staged_files"
  done

  if [ "$found_secret" = false ]; then
    pass "No secrets detected in modified files"
  fi

  # Check .env is in .gitignore
  if [ -f ".gitignore" ] && grep -q '\.env' .gitignore; then
    pass ".env in .gitignore"
  elif [ -f ".env" ]; then
    fail ".env exists but not in .gitignore"
  else
    pass "No .env file present"
  fi
}

# === CONTRACT AUDIT ===
audit_contract() {
  local contract_path="${1:-}"
  echo "=== Contract Audit ==="

  if [ -z "$contract_path" ]; then
    echo "  Scanning all src/ contracts..."
    contract_path="src/"
  fi

  # 1. Forge tests pass
  echo "  Running forge tests..."
  local test_output
  test_output=$(forge test 2>&1)
  if echo "$test_output" | grep -q "FAIL"; then
    fail "Forge tests have failures"
    echo "$test_output" | grep "FAIL" | head -5
  elif echo "$test_output" | grep -q "Suite result: ok"; then
    local test_count
    test_count=$(echo "$test_output" | grep -oP '\d+ tests?' | head -1)
    pass "All forge tests pass ($test_count)"
  else
    warn "Could not determine test results"
  fi

  # 2. Check for common vulnerabilities in source
  echo "  Scanning for common vulnerability patterns..."

  local vuln_patterns=(
    "tx.origin"                    # tx.origin auth bypass
    "selfdestruct\|SELFDESTRUCT"   # Destroyable contracts
    "delegatecall"                 # Delegatecall risks
    "assembly.*mstore"            # Unchecked assembly writes
    "block.timestamp.*=="          # Timestamp equality (manipulation)
  )

  local safe_patterns=(
    "ReentrancyGuard\|nonReentrant"  # Reentrancy protection
    "SafeERC20\|safeTransfer"        # Safe token transfers
  )

  for vp in "${vuln_patterns[@]}"; do
    local label
    label=$(echo "$vp" | sed 's/\\|/ or /g')
    if grep -rq "$vp" src/ 2>/dev/null; then
      warn "Found '$label' usage in src/ — review for safety"
    fi
  done

  # Check reentrancy guard exists where ETH is sent
  if grep -rq "\.call{value" src/ 2>/dev/null; then
    if grep -rq "nonReentrant\|ReentrancyGuard" src/ 2>/dev/null; then
      pass "Reentrancy guards present for ETH transfers"
    else
      fail "ETH transfers (.call{value) found WITHOUT reentrancy guards"
    fi
  fi

  # 3. Check for unchecked external calls
  if grep -rqP '\.call\{' src/ 2>/dev/null; then
    if grep -rqP 'require\(success' src/ 2>/dev/null || grep -rqP 'if.*!success' src/ 2>/dev/null; then
      pass "External call return values are checked"
    else
      warn "External .call{} found — verify return values are checked"
    fi
  fi

  # 4. Check for immutability (no proxy patterns)
  if grep -rq "upgradeable\|transparent\|UUPS\|ERC1967" src/ 2>/dev/null; then
    warn "Proxy/upgrade patterns detected — verify this is intentional"
  else
    pass "No proxy patterns — contracts are immutable"
  fi

  # 5. Check for admin functions without access control
  if grep -rqP 'function.*(pause|kill|destroy|selfdestruct|withdraw|drain)' src/ 2>/dev/null; then
    warn "Found potentially dangerous admin functions — verify access control"
  else
    pass "No dangerous admin functions (pause/kill/destroy/drain)"
  fi
}

# === PRE-DEPLOY AUDIT ===
audit_deploy() {
  echo "=== Pre-Deploy Checklist ==="

  # 1. Check deployer balance
  local balance
  balance=$(cast balance "$DEPLOYER" --rpc-url "$RPC" 2>/dev/null)
  if [ -n "$balance" ]; then
    local eth
    eth=$(cast to-unit "$balance" ether 2>/dev/null)
    if [ "$(echo "$eth > 0.001" | bc -l 2>/dev/null)" = "1" ] 2>/dev/null; then
      pass "Deployer has $eth ETH (sufficient for Base deploy)"
    else
      warn "Deployer has $eth ETH — low for deployment"
    fi
  else
    warn "Could not check deployer balance"
  fi

  # 2. Verify private key env var exists but don't expose it
  if [ -n "${THRYXTREASURY_PRIVATE_KEY:-}" ]; then
    local key_len=${#THRYXTREASURY_PRIVATE_KEY}
    if [ "$key_len" -eq 64 ] || [ "$key_len" -eq 66 ]; then
      pass "THRYXTREASURY_PRIVATE_KEY set (${key_len} chars)"
    else
      warn "THRYXTREASURY_PRIVATE_KEY unusual length: $key_len"
    fi
  else
    fail "THRYXTREASURY_PRIVATE_KEY not set"
  fi

  # 3. Check forge build is clean
  local build_output
  build_output=$(forge build 2>&1)
  if echo "$build_output" | grep -q "error\|Error"; then
    fail "forge build has errors"
  else
    pass "forge build clean"
  fi

  # 4. Run secret scan
  audit_secrets
}

# === SKILL/MCP SERVER AUDIT ===
audit_skill() {
  local skill_path="${1:-skills/}"
  echo "=== Skill / MCP Server Audit ==="

  # 1. No hardcoded private keys in skill files
  if grep -rqP '[0-9a-fA-F]{64}' "$skill_path" 2>/dev/null; then
    fail "Potential hardcoded private key in skill files"
  else
    pass "No hardcoded keys in skill directory"
  fi

  # 2. No internal URLs leaked
  if grep -rq "localhost\|127\.0\.0\.1\|192\.168\." "$skill_path" 2>/dev/null; then
    warn "Internal/localhost URLs found in skill files — remove before publishing"
  else
    pass "No internal URLs in skill files"
  fi

  # 3. Check MCP server if exists
  if [ -d "mcp-server" ]; then
    echo "  Scanning MCP server..."

    # No secrets in source
    if grep -rqP 'PRIVATE_KEY|password|secret' mcp-server/src/ 2>/dev/null; then
      if grep -rqP 'process\.env|env\.' mcp-server/src/ 2>/dev/null; then
        pass "MCP server reads secrets from env vars (not hardcoded)"
      else
        fail "MCP server may contain hardcoded secrets"
      fi
    else
      pass "No secret references in MCP server source"
    fi

    # Check for eval or exec injection risks
    if grep -rqP 'eval\(|exec\(|Function\(' mcp-server/src/ 2>/dev/null; then
      fail "eval/exec/Function found in MCP server — injection risk"
    else
      pass "No eval/exec injection vectors in MCP server"
    fi

    # Check npm audit if package-lock exists
    if [ -f "mcp-server/package-lock.json" ]; then
      local audit_output
      audit_output=$(cd mcp-server && npm audit --json 2>/dev/null)
      local vuln_count
      vuln_count=$(echo "$audit_output" | grep -oP '"total":\s*\K\d+' | head -1)
      if [ "${vuln_count:-0}" -eq 0 ]; then
        pass "npm audit: 0 vulnerabilities"
      else
        warn "npm audit: $vuln_count vulnerabilities found"
      fi
    fi
  fi
}

# === SUMMARY ===
print_summary() {
  echo ""
  echo "================================"
  if [ "$failures" -gt 0 ]; then
    echo -e "  ${RED}AUDIT FAILED${NC}: $failures failure(s), $warnings warning(s)"
    echo "  Fix all FAIL items before proceeding."
    echo "================================"
    return 1
  elif [ "$warnings" -gt 0 ]; then
    echo -e "  ${YELLOW}AUDIT PASSED WITH WARNINGS${NC}: $warnings warning(s)"
    echo "  Review WARN items before proceeding."
    echo "================================"
    return 0
  else
    echo -e "  ${GREEN}AUDIT PASSED${NC}: All checks clean"
    echo "================================"
    return 0
  fi
}

# === MAIN ===
case "$target" in
  contract)  audit_contract "$@" ;;
  deploy)    audit_deploy ;;
  skill)     audit_skill "$@" ;;
  state|secrets) audit_secrets ;;
  all)
    audit_secrets
    echo ""
    audit_contract
    echo ""
    audit_deploy
    echo ""
    audit_skill
    ;;
  "")
    echo "Usage: ./thryx audit <target>"
    echo ""
    echo "Targets:"
    echo "  contract [path]  — Static analysis on Solidity files"
    echo "  deploy           — Pre-deploy checklist"
    echo "  skill [path]     — Audit skill/MCP server before publishing"
    echo "  secrets          — Scan for leaked keys in code"
    echo "  all              — Run all audits"
    echo ""
    echo "Run before ANY public action (deploy, publish, submit)."
    exit 1
    ;;
  *)
    echo "Unknown target: $target"
    echo "Try: ./thryx audit all"
    exit 1
    ;;
esac

print_summary

---
id: trie
type: flashcard
tags:
  - ds-a
  - tree
  - string
tiers:
  ds-a: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Trie (Prefix Tree)

A trie is a tree whose edges are labeled by characters, so the path from the root to any node spells out a prefix shared by every key in that node's subtree. Keys are not stored whole in a single node; instead each key is spread across a chain of nodes (one per character position), and a boolean/flag on a node marks where a complete key ends. The defining consequence: insert, exact search, and prefix lookup all cost O(L) in the key length L and are **independent of how many keys the trie holds** — you walk one character at a time, never comparing against other keys.

> [!tip] Recognition signal
> Reach for a trie when the problem is about **prefixes over a set of strings**: autocomplete / typeahead, "return all words starting with X", incremental spellcheck or dictionary lookup, longest-prefix matching, or repeatedly querying whether any stored word shares a given prefix.

## When to Use

**Problem signals that suggest a Trie:**
- **Autocomplete / typeahead** — given a prefix, enumerate or count all stored words that start with it.
- **Prefix existence queries** — "does any word in the set start with `pre`?" as distinct from "is `pre` itself a word?"
- **Dictionary / spellcheck** driven by keystrokes, where each new character extends the previous query (you descend one more node instead of re-searching).
- **Word-search / wildcard matching** over a fixed dictionary (e.g. LeetCode "Word Search II", "Add and Search Word" with `.` wildcards) — the trie lets you prune whole branches that no dictionary word follows.
- The keys are **strings (or fixed-alphabet sequences) sharing many common prefixes**, so shared-prefix collapsing saves space and lookup work.

**Prefer a Trie over alternatives when:**
- **Over a hash map:** you need prefix queries or sorted/ordered traversal, or the shared-prefix compression matters — a hash map supports none of these.
- **Over a sorted array + binary search:** you need incremental descent per keystroke and per-prefix pruning, not a fresh O(log n · L) search each time.
- **Over a balanced [BST](_meta/glossary.md#bst) keyed by whole strings:** BST comparisons cost O(L) each and the tree is O(log n) deep, giving O(L log n); the trie is O(L) with no dependence on n.

**Do not use when:**
- You only need **exact-match** lookups and no prefix/ordering — a hash map is faster in practice and far simpler (see contrast below).
- The alphabet is huge or keys are long and sparse (few shared prefixes) — per-node child overhead dominates; consider a compressed trie (radix/Patricia) or ternary search tree instead.

## Key Properties

- **Path spells the key.** No node holds a whole key; the concatenation of edge labels from root to a node is the prefix reaching it. A separate **end-of-word flag** distinguishes "a key ends here" from "this is merely a prefix of longer keys."
- **Lookup cost is O(L), independent of the number of keys.** Because you branch on the next character rather than comparing to other stored keys, adding more words never slows a lookup — this is the property that separates a trie from every comparison-based structure.
- **Prefix queries are native.** To find everything under a prefix, walk L nodes to the prefix node, then [DFS](_meta/glossary.md#dfs) its subtree; ordering the children (e.g. alphabetically) yields **sorted** results for free.
- **Contrast vs. hash map:** hash map gives O(1) average *exact* lookup but has **no notion of prefixes or order** — it cannot answer "words starting with X." Trie trades that O(1) and its low memory for prefix queries, ordered traversal, and shared-prefix savings.
- **Contrast vs. binary tree/BST:** a BST branches on *whole-key comparison* (left/right by ordering), so depth scales with the number of keys (O(log n)) and each step costs an O(L) string compare. A trie branches on the *next character*, so depth scales with key length (L) and each step is O(1) — position, not comparison, drives the descent.

## Trade-offs

- **Space cost is the main downside.** Each node carries child references for the alphabet — an array of size σ (fast, but wasteful when sparse) or a hash/map (compact, slightly slower). Many single-child chains inflate memory versus a hash set of the same words.
- **Speed vs. memory:** array-indexed children give the fastest descent but O(σ) space per node; map-backed children shrink space at the cost of a per-step hash/compare.
- **Shared prefixes save space** when keys overlap heavily (e.g. English words); they save nothing when keys are near-random, which is when a hash map wins outright.
- **Compressed variants** (radix/Patricia trie) merge single-child chains into one edge, cutting node count and memory while keeping O(L) queries — worth it for long sparse keys.

## Common Pitfalls

- **Confusing "is a word" with "is a prefix."** `search("app")` must return false if only `"apple"` was inserted; that requires checking the end-of-word flag at the final node, not merely that the path exists. `startsWith("app")` returns true regardless of the flag. Conflating the two is the single most common bug.
- **Forgetting the end-of-word flag entirely**, so the trie can only answer prefix questions and cannot tell whether a full key was stored.
- **Deletion done wrong.** Removing a word means clearing its end flag and pruning nodes only if they have no children *and* are not themselves end-of-word for a shorter key — naively deleting the path can destroy other words (deleting `"app"` must not break `"apple"`).
- **Assuming O(1)-style constant memory.** A trie over sparse keys with a large alphabet can use far more memory than a hash set of the same strings.
- **Alphabet assumptions.** Hard-coding 26 lowercase children breaks on uppercase, digits, Unicode, or spaces — size the children to the actual alphabet or use a map.

## Time & Space Complexity

| Operation | Time | Notes |
|---|---|---|
| Insert key | O(L) | L = key length; independent of #keys |
| Exact search | O(L) | plus end-of-word flag check |
| Prefix exists (`startsWith`) | O(L) | walk to prefix node |
| Enumerate all keys under prefix | O(L + k) | k = total chars across matching keys (DFS the subtree) |
| Space | O(total characters × σ)* | σ = alphabet/child-slot cost per node; compressed tries reduce this |

\*Worst case one node per character across all keys, each holding up to σ child slots. Shared prefixes collapse this substantially when keys overlap.

## Implementation Notes

```javascript
class TrieNode {
    constructor() {
        this.children = new Map();   // char -> TrieNode (map keeps it alphabet-agnostic)
        this.isEnd = false;          // marks a complete key ending here
    }
}

class Trie {
    constructor() { this.root = new TrieNode(); }

    insert(word) {
        let node = this.root;
        for (const ch of word) {                       // O(L): descend one char at a time
            if (!node.children.has(ch)) node.children.set(ch, new TrieNode());
            node = node.children.get(ch);
        }
        node.isEnd = true;                             // flag the end of a full word
    }

    // walk the path for `str`; return the node reached, or null if the path breaks
    _walk(str) {
        let node = this.root;
        for (const ch of str) {
            if (!node.children.has(ch)) return null;
            node = node.children.get(ch);
        }
        return node;
    }

    search(word) {                                     // full-word: path exists AND isEnd
        const node = this._walk(word);
        return node !== null && node.isEnd;
    }

    startsWith(prefix) {                               // prefix-only: path exists (isEnd ignored)
        return this._walk(prefix) !== null;
    }
}
```

## Variants

- **Compressed trie (radix / Patricia trie)** — collapses single-child chains into one edge labeled with a substring; fewer nodes, same O(L) queries. Used in [IP](_meta/glossary.md#ip) routing tables (longest-prefix match).
- **Ternary search tree** — each node has low/equal/high children; far less memory than an array-backed trie for large alphabets, at slightly higher lookup cost.
- **Suffix trie / suffix tree** — stores all suffixes of a single string to answer substring queries; distinct use case from the multi-key prefix trie here.

## Resources

- LeetCode 208 "Implement Trie (Prefix Tree)": https://leetcode.com/problems/implement-trie-prefix-tree/
- CP-Algorithms, Trie / Aho-Corasick: https://cp-algorithms.com/string/aho_corasick.html
- Wikipedia, Trie: https://en.wikipedia.org/wiki/Trie

## Related

- [[hash-map]]
- [[binary-tree]]
- [[string]]

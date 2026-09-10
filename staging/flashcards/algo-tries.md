---
id: algo-tries
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 3
created: 2026-09-10
confidence: high
---

# Tries

Reach for a trie when the problem is about strings sharing prefixes: a tree keyed by one character per edge lets you store, search, and prefix-match a whole dictionary in time proportional to word length rather than dictionary size. The tell is any task that repeatedly asks "does a word/prefix exist?", "which stored words start like this?", or that needs to prune a search over a large word list as you walk letter by letter. Solve each on your own machine, then log how it went.

## Implement Trie (Prefix Tree)
[Solve on LeetCode](https://leetcode.com/problems/implement-trie-prefix-tree/) · Medium

**Problem.** Build a data structure that stores lowercase words and supports three operations: insert a word, check whether a full word was inserted before, and check whether any inserted word begins with a given prefix. All three should be efficient in the length of the argument, not the number of stored words.

**Example.** After inserting `"code"`, calling `search("code")` -> `true`, `search("cod")` -> `false` (not a complete word), but `startsWith("cod")` -> `true` because a stored word has that prefix.

**Recognition.** "Insert words, then query full-word vs. prefix membership" is the canonical trie. Give each node a map/array of child links plus an `isEnd` flag; walk one character per node, and distinguish `search` (must land on a node with `isEnd`) from `startsWith` (just reach the node).

## Design Add and Search Words Data Structure
[Solve on LeetCode](https://leetcode.com/problems/design-add-and-search-words-data-structure/) · Medium

**Problem.** Support adding words and searching for them, except a search string may contain `.` as a wildcard that matches any single character. `addWord` stores a word; `search` returns whether any stored word matches the pattern, treating each `.` as "any one letter".

**Example.** After adding `"bad"` and `"dad"`, `search("b.d")` -> `true` (the `.` matches `a`), `search(".ad")` -> `true` (either stored word fits), and `search("b..")` -> `true` since `bad` satisfies both wildcards, while `search("ba")` -> `false` because no two-letter word was stored.

**Recognition.** A trie plus a wildcard forces branching search. On a literal char descend the single matching child; on a `.` recurse into every existing child (DFS/backtracking over the node's children), succeeding if any branch reaches an `isEnd` node at the pattern's end.

## Word Search II
[Solve on LeetCode](https://leetcode.com/problems/word-search-ii/) · Hard

**Problem.** Given a grid of letters and a list of target words, return every word from the list that can be traced by moving between horizontally or vertically adjacent cells, where no single cell is reused within one word. You must find all matches over the whole dictionary at once, not one word per scan.

**Example.** For a small board and words `["oath", "pea", "eat", "rain"]`, the answer might be `["oath", "eat"]` — the two that can be spelled by a connected, non-repeating cell path, while `rain` cannot be traced.

**Recognition.** Many words to find on one board means build a trie of the words, then DFS the grid guided by it: at each cell only continue down the trie if the current letter is a child, prune dead branches immediately, and record a word when you hit an `isEnd`. Backtrack the visited mark and trim matched leaves to keep the search cheap.

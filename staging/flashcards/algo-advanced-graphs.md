---
id: algo-advanced-graphs
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 3
created: 2026-09-10
confidence: high
---

# Advanced Graphs

Reach for this group when a plain BFS/DFS is not enough because edges carry weights, an ordering must be discovered, or you must stitch a whole trail or tree together under a cost objective. The tell is any question mentioning shortest/cheapest path with weights, minimum total connection cost, a valid ordering from partial constraints, or using up every edge exactly once — cues for Dijkstra, Bellman-Ford, minimum spanning tree, topological sort, or Hierholzer's Eulerian walk. Solve each on your own machine, then log how it went.

## Reconstruct Itinerary
[Solve on LeetCode](https://leetcode.com/problems/reconstruct-itinerary/) · Hard

**Problem.** You are given a list of airline tickets, each a `[from, to]` pair, and must arrange them into a single continuous journey that starts at `"JFK"` and uses every ticket exactly once. All tickets are guaranteed to form one valid itinerary; when several orderings are possible, return the one that is smallest in lexical order.

**Example.** Tickets `[["JFK","B"],["JFK","A"],["A","JFK"]]` -> `["JFK","A","JFK","B"]` because starting `JFK->A` (lexically before `B`) lets you consume all three tickets.

**Recognition.** "Use every edge exactly once" is an Eulerian path; the lexical tie-break is the giveaway. Sort each node's destinations, then run Hierholzer's algorithm (DFS that appends a node to the route only after exhausting its outgoing edges) and reverse the result.

## Min Cost to Connect All Points
[Solve on LeetCode](https://leetcode.com/problems/min-cost-to-connect-all-points/) · Medium

**Problem.** You are given points on a 2D plane, and the cost to link any two of them is their Manhattan distance. Return the smallest total cost needed so that every point is reachable from every other, i.e. the whole set forms one connected network.

**Example.** Points `[(0,0),(0,3),(4,0)]` -> `7`: connect `(0,0)-(0,3)` for `3` and `(0,0)-(4,0)` for `4`, leaving all three joined.

**Recognition.** "Connect everything for the minimum total edge cost" is a minimum spanning tree. Since any pair can be an edge, run Prim's algorithm from any node with a min-heap keyed on distance to the growing tree (dense-graph friendly), or Kruskal with union-find.

## Network Delay Time
[Solve on LeetCode](https://leetcode.com/problems/network-delay-time/) · Medium

**Problem.** You have a directed network of nodes with weighted travel times on each edge, and a signal starts at a given source node. Return how long until every node has received the signal — the maximum over all nodes' shortest arrival times — or `-1` if some node can never be reached.

**Example.** Edges `[(1,2,1),(2,3,2)]` from source `1` with `3` nodes -> `3`, since node `3` arrives last at time `1+2`.

**Recognition.** "Time for a signal to reach all nodes" is the longest of the single-source shortest paths on a weighted graph. Run Dijkstra from the source with a min-heap, then return the largest finalized distance (or `-1` if any node stays unreached).

## Swim in Rising Water
[Solve on LeetCode](https://leetcode.com/problems/swim-in-rising-water/) · Hard

**Problem.** Given an `n x n` grid where each cell holds an elevation, water rises so that at time `t` any cell with elevation at most `t` is submerged. You start top-left and want to reach bottom-right, moving between 4-directionally adjacent submerged cells. Return the earliest time you can arrive.

**Example.** Grid `[[0,2],[1,3]]` -> `3`: you cannot leave the corner until the `3` cell is under water, so the exit opens at time `3`.

**Recognition.** "Minimize the maximum cell value along a path" is a min-max path problem. Use a Dijkstra-style min-heap where a path's cost is the largest elevation seen so far, always expanding the lowest-max frontier until you pop the destination (binary-search-plus-DFS also works).

## Alien Dictionary
[Solve on LeetCode](https://leetcode.com/problems/alien-dictionary/) · Hard

**Problem.** You are given words sorted according to an unknown alphabet's ordering, and must deduce a possible ordering of that alphabet's letters. Return any valid letter order as a string, or the empty string if the given sorting is contradictory. Note that if a word is a prefix of a longer word yet appears after it, the input is invalid.

**Example.** Words `["ba","bc","ac"]` -> `"bac"`: `ba` before `bc` gives `a<c`, and `bc` before `ac` gives `b<a`, so the order is `b, a, c`.

**Recognition.** "Derive an ordering from pairwise constraints" is a topological sort. Compare each adjacent word pair to extract one letter-precedence edge (guarding the invalid-prefix case), then Kahn's BFS or DFS on that graph; a cycle means return `""`.

## Cheapest Flights Within K Stops
[Solve on LeetCode](https://leetcode.com/problems/cheapest-flights-within-k-stops/) · Medium

**Problem.** Given cities connected by directed, priced flights, find the cheapest fare from a source to a destination using at most `k` intermediate stops. Return the minimum total price, or `-1` if no route respects the stop limit.

**Example.** Flights `[(0,1,100),(1,2,100),(0,2,500)]`, from `0` to `2` with `k=0` -> `500`, because the two-hop `0->1->2` path exceeds the zero-stop budget.

**Recognition.** "Cheapest path with a hard cap on the number of edges" is Bellman-Ford limited to `k+1` relaxation rounds. Relax all edges exactly `k+1` times using a snapshot of the previous round's costs so each pass adds at most one more hop.

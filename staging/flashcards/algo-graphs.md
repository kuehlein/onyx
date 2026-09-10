---
id: algo-graphs
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 2
created: 2026-09-10
confidence: high
---

# Graphs

Reach for graph traversal when the data is a network of nodes with edges — an explicit adjacency list, a grid where neighbors connect, or dependencies between tasks — and you need to explore reachability, count components, find shortest hops, or detect cycles. The tell is "connected", "reach", "shortest number of steps", "order that respects prerequisites", or "does adding this edge create a loop". DFS/BFS flood a region, BFS gives shortest unweighted distance, topological sort orders a DAG, and union-find tracks connectivity as edges arrive. Solve each on your own machine, then log how it went.

## Number of Islands
[Solve on LeetCode](https://leetcode.com/problems/number-of-islands/) · Medium

**Problem.** You are given a 2D grid of cells marked land or water. Land cells that touch horizontally or vertically form an island. Count how many separate islands the grid contains. Diagonal touching does not connect land.

**Example.** In a grid where the top-left 2x2 block is land, everything else water -> `1` island; if there is also an isolated land cell in a far corner -> `2`.

**Recognition.** "Count connected land regions in a grid" is the cue. Scan every cell; on an unvisited land cell, flood-fill (DFS/BFS) to sink its whole island, then bump the counter.

## Max Area of Island
[Solve on LeetCode](https://leetcode.com/problems/max-area-of-island/) · Medium

**Problem.** Given a grid of land and water cells where connected land (up/down/left/right) forms an island, return the size in cells of the largest island. If there is no land at all, the answer is zero.

**Example.** An island of `5` connected land cells and another of `3` -> `5`.

**Recognition.** Same flood-fill as counting islands, but each flood returns the count of cells it visited. Track the running maximum across all starts.

## Clone Graph
[Solve on LeetCode](https://leetcode.com/problems/clone-graph/) · Medium

**Problem.** You are given a reference to one node of a connected undirected graph; each node holds a value and a list of neighbors. Build and return a deep copy: a completely new set of nodes mirroring the original structure, sharing no objects with it.

**Example.** A triangle `A-B-C` (each connected to the other two) -> three brand-new nodes `A'-B'-C'` wired the same way.

**Recognition.** "Deep-copy a graph" means traverse while remembering what you already cloned. Keep a map from original node to its copy; on visiting a node, create its clone once, then recurse to wire up cloned neighbors.

## Walls and Gates
[Solve on LeetCode](https://leetcode.com/problems/walls-and-gates/) · Medium

**Problem.** Given a grid where cells are walls (blocked), gates, or empty rooms marked with a sentinel "infinity", fill each empty room with its distance to the nearest gate, moving only through open cells. Rooms that cannot reach any gate keep the infinity value. Update the grid in place.

**Example.** A room two steps from the closest gate (no wall between) becomes `2`; a room walled off from every gate stays infinity.

**Recognition.** "Shortest distance from many sources" is multi-source BFS. Seed the queue with every gate at distance 0 and expand outward simultaneously, filling each empty room the first time it is reached.

## Rotting Oranges
[Solve on LeetCode](https://leetcode.com/problems/rotting-oranges/) · Medium

**Problem.** In a grid, cells are empty, hold a fresh orange, or hold a rotten orange. Each minute, every rotten orange rots its fresh orthogonal neighbors. Return the number of minutes until no fresh orange remains, or -1 if some fresh orange can never rot.

**Example.** A row `fresh, rotten, fresh` -> `1` minute (both neighbors rot together); an isolated fresh orange with no rotten neighbor ever -> `-1`.

**Recognition.** "Simultaneous spread over time, count the minutes" is level-order multi-source BFS. Start with all rotten oranges in the queue, process the frontier one minute per level, and at the end check no fresh orange survived.

## Pacific Atlantic Water Flow
[Solve on LeetCode](https://leetcode.com/problems/pacific-atlantic-water-flow/) · Medium

**Problem.** Given a grid of cell heights, the Pacific borders the top and left edges and the Atlantic borders the bottom and right edges. Water flows from a cell to an equal-or-lower neighbor. Return every cell from which water can reach both oceans.

**Example.** A cell on the top-left corner trivially touches the Pacific; a peak high enough to drain toward both edges -> included in the result.

**Recognition.** Instead of testing each cell forward, reverse the flow: BFS/DFS inward from each ocean's border to mark cells that can reach it (uphill or level). The answer is the intersection of the two reachable sets.

## Surrounded Regions
[Solve on LeetCode](https://leetcode.com/problems/surrounded-regions/) · Medium

**Problem.** Given a grid of `X` and `O` cells, capture every region of `O`s that is fully enclosed by `X`s by flipping those `O`s to `X`. An `O` region survives only if it touches the grid border. Modify the board in place.

**Example.** An `O` block hugging the left edge stays `O`; an interior `O` region with `X` on all sides -> flipped to `X`.

**Recognition.** "Enclosed unless connected to the boundary" — work from the edges. Flood-fill every border-connected `O` and mark it safe; then flip all remaining (unmarked) `O`s to `X`.

## Course Schedule
[Solve on LeetCode](https://leetcode.com/problems/course-schedule/) · Medium

**Problem.** You have a number of courses and a list of prerequisite pairs meaning "take A before B". Decide whether it is possible to finish all courses, i.e. whether a valid ordering exists. Return a boolean.

**Example.** Prereqs `1->0` and `0->1` (each needs the other) -> `false` (a cycle); `1->0` alone -> `true`.

**Recognition.** "Can all tasks be completed given dependencies" reduces to cycle detection on a directed graph. Run topological sort (Kahn's indegree peeling or DFS coloring); it is feasible exactly when no cycle exists.

## Course Schedule II
[Solve on LeetCode](https://leetcode.com/problems/course-schedule-ii/) · Medium

**Problem.** Same prerequisite setup as Course Schedule, but now return an actual ordering of all courses that respects every prerequisite. If no valid ordering exists (a cycle), return an empty list.

**Example.** Courses `0..2` with prereqs `0->1` and `1->2` -> `[0, 1, 2]`; a cyclic set -> `[]`.

**Recognition.** "Produce a valid dependency order" is topological sort itself. Peel nodes with zero indegree via BFS, appending each as you go; if you emit fewer than all courses, a cycle blocked it.

## Graph Valid Tree
[Solve on LeetCode](https://leetcode.com/problems/graph-valid-tree/) · Medium

**Problem.** Given `n` nodes and a list of undirected edges, decide whether the graph forms a valid tree — meaning it is fully connected and contains no cycle. Return a boolean.

**Example.** `4` nodes with edges forming a single line `0-1-2-3` -> `true`; the same nodes with an extra edge `0-3` closing a loop -> `false`.

**Recognition.** A tree on `n` nodes has exactly `n-1` edges and is connected. Check the edge count, then confirm everything is reachable from one node (BFS/DFS) or that union-find merges all nodes with no premature union.

## Number of Connected Components in an Undirected Graph
[Solve on LeetCode](https://leetcode.com/problems/number-of-connected-components-in-an-undirected-graph/) · Medium

**Problem.** Given `n` nodes labeled `0..n-1` and a list of undirected edges, count how many connected components the graph has. Isolated nodes with no edges each count as their own component.

**Example.** `5` nodes with edges `0-1`, `1-2`, and `3-4` -> `2` components (`{0,1,2}` and `{3,4}`).

**Recognition.** "Count separate clusters" is union-find (or repeated flood-fill). Start with `n` components and decrement each time an edge joins two previously separate sets.

## Redundant Connection
[Solve on LeetCode](https://leetcode.com/problems/redundant-connection/) · Medium

**Problem.** You start with a tree and one extra undirected edge was added, creating exactly one cycle. Given the edges in order, return the edge that can be removed so the graph becomes a tree again. If several qualify, return the one appearing last in the input.

**Example.** Edges `1-2`, `2-3`, `1-3` -> `[1, 3]`, the edge that closes the cycle.

**Recognition.** "Find the edge that creates the cycle" is textbook union-find. Union endpoints one edge at a time; the first edge whose two endpoints are already in the same set is the redundant one.

## Word Ladder
[Solve on LeetCode](https://leetcode.com/problems/word-ladder/) · Hard

**Problem.** Given a start word, an end word, and a dictionary of allowed words, transform the start into the end by changing one letter at a time, where every intermediate word must be in the dictionary. Return the length of the shortest such transformation chain (including both ends), or 0 if none exists.

**Example.** `"hit"` -> `"cog"` via `hit -> hot -> cot -> cog` -> `4`; if no valid chain of dictionary words connects them -> `0`.

**Recognition.** "Fewest one-letter mutations between words" is a shortest-path over an implicit graph, so BFS. Treat each word as a node with edges to dictionary words one letter apart (build neighbors via wildcard patterns like `h*t`), and BFS levels give the answer.

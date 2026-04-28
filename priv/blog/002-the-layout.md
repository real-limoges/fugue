---
title: The Layout
date: 2026-04-26
tags: fugue, architecture
summary: This is the first of hopefully many blog posts.
draft: false
---

Architecture is a lost art in the age of Claude and ChatGPT. Too often we rush into things and leave the
consequences for later. I chose to take a step back to think how to make this project sing; I made the
conscious choice to pick the **best** thing to achieve my goals, not the most convenient. The 35,000 foot view:

<br>

- **Elixir** - The Phoenix framework chosen for this site. It's excellent at threading together a website with its
strictly functional/immutable style. In Elixir (and Erlang) data isn't shared between threads and enforces strict
isolation. It works for this site, which is mostly stateless, and it works at incredible scale, say for a chat room.

<br>

- **Haskell** - A purely functional, stateless langugage that lets me be transparent about what I am doing with my data.
It's really challenging but it forces you to write clean code. With it, I can pass functions over data fearlessly.

<br>

- **WASM / C** - A few of the math demonstractions (Boids, Oscillators, etc.) were written in C and compiled to WASM.
I wanted to bring the computation to the client since they're relatively high FPS demonstrations.

<br>

- **Rust** - I built a large side project to parse and visualize Wikipedia. Unfortunately, it is not going to make
it onto the site, but its worth mentioning that it was part of the stack.

<br>

I chose to break everything up rather than have a huge monorepo. I deploy different containers on GCP in different
Cloud Run instances. I continuously deploy any of my changes.

<br>

## **\- Real**

<br>

*I feel an obligation to say this: I had to use JavaScript on this site. Even in this modern world, the dinosaur
of JavaScript still is around as the only language available for hoisting things client side. Even if you built
perfecly tuned WASM + Elixir, you still have to write a hook.*
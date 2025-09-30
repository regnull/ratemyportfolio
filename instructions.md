I want to create a web app, "Rate My Portfolio". Here's the description:

- the app must be written in next.js
- this is a web app
- it will allow users to check their portfolio and rate it
- the front page will have a control where users will be able to upload files, which can be files describing the portfolio, screenshots, or any other files describing the positions.
- on the front page, there is also a control to indicate the risk tolerance - conservative, moderate, aggressive or extremely aggressive.
- once a user uploads the files and selects the risk tolerance the user will click
"Rate my portfolio" button
- when this happen, the files and the goal will be sent to the backend, where we will invoke an LLM with a proper prompt. The LLM will
respond with portfolio rating, along a few axis (risk, growth, alighnment with the goal, etc). It will also provide text discussing the
positions and how they contribute to the goal. If there is a misalignment, it will discuss it and suggest improvements. Actually, it
should suggest improvements in most cases.
- the user will be able to share this page (there is a "share" button on the results page), either by email, text (link to the page), or
any other way
- The app must be slick and attractive, with appealing visual style

The process:

- before coding, investigate the idea completely and come up with a comprehensive plan. Think.
- implement the plan. Follow the generally accepted software development principles
- document your work, including the required configuration for the system.
- test your work as much as possible. If you need user intervention, for example to configure the OPENAI key, stop and ask for it.

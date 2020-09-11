---
layout: page
title: About
permalink: /about/
weight: 3
---

# **About Me**

Hi I am **{{ site.author.name }}** :wave:,<br>
This page serves as a very digestible overview of who I am and what past experience I have.
I don't really like putting percentages on skills, I believe in being in a constate state of learning and staying humble to the unknown and undiscovered. If you like what you see here, feel free to check out my LinkedIn profile!

# <a href="https://www.linkedin.com/in/hugil"><i class="fab fa-linkedin-in fa-1x"></i> LinkedIn</a>

<div class="row">
{% include about/skills.html title="Skills" source=site.data.skills %}
{% include about/skills.html title="Programming" source=site.data.programming %}
</div>

<div class="row">
{% include about/timeline.html %}
</div>
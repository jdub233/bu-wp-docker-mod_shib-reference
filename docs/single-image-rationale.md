
## Summary: Revisiting the Two-Image Build Approach

### Current Design

- The system currently builds two images:
    - A custom base image, extending the official WordPress image with needed PHP extensions (like igbinary, shibboleth).
    - An application image, based on the custom base, which adds the WordPress code bundle.
- This model was likely chosen for **layering, cache efficiency, and separation of responsibilities**.


### Challenges with Newer Docker/Buildx Workflows

- With recent Docker and Buildx updates, multiplatform builds and default use of containerized builders cause image isolation:
    - Images built locally in one build step are **not directly available** to subsequent build steps without pushing to a local/remote registry.
    - This breaks traditional workflows where one could quickly layer images without network dependencies or registry configuration.
- **Developer onboarding and troubleshooting** become harder, as teams without advanced Docker knowledge now must manage multi-image workflows, image visibility, and registry operations even for local builds.[^1]


### Proposed Alternative: Single Multi-Stage Dockerfile

- Consolidating the build process into **one Dockerfile**, where dependencies and code are layered efficiently:
    - **Removes local image chaining issues**—build cache remains available and each change triggers a rebuild only for affected layers.
    - **Simplifies onboarding:** New developers only need to run one build, without worrying about registry configuration or image dependencies.
    - **Maintains cache efficiency:** Docker's caching still ensures dependency installation (e.g., extensions) doesn't re-run unless that part of the Dockerfile actually changes.


### Technical and Organizational Rationale

- **For local and CI builds:** This approach works seamlessly in modern Docker/Buildx without extra steps or workarounds.[^1]
- **For maintainability:** Documentation and workflows become easier, reducing cognitive overhead for new contributors.
- **Future flexibility:** If a shared base image becomes necessary (for multiple downstream projects), the two-image approach can be reintroduced as team needs evolve.


### Recommendation

Consolidating to a single, well-structured Dockerfile (using multi-stage or not, as needed) will:

- Increase developer velocity and reduce setup friction
- Remove problems caused by new builder/image isolation in recent Docker and Buildx versions
- Keep the build process efficient and maintainable with current technology

This change is based on a careful review of Docker practices and modern build system limitations; it aligns with both current tooling and the team's needs.

---
<span style="display:none">[^2][^3][^4][^5][^6][^7][^8]</span>

<div style="text-align: center">⁂</div>

[^1]: https://www.reddit.com/r/docker/comments/w2r4os/two_dockerfiles_vs_multistage_vs_just_one_big/

[^2]: https://stackoverflow.com/questions/34316047/difference-between-image-and-build-within-docker-compose

[^3]: https://stackoverflow.com/questions/72116192/what-is-the-difference-between-docker-image-build-and-docker-build

[^4]: https://www.baeldung.com/ops/docker-differences-between-images

[^5]: https://forums.docker.com/t/is-there-any-difference-to-create-images-between-these-two-ways/67422

[^6]: https://docs.docker.com/reference/cli/docker/scout/compare/

[^7]: https://docs.docker.com/build/building/multi-stage/

[^8]: https://forums.docker.com/t/differences-between-standard-docker-images-and-alpine-slim-versions/134973


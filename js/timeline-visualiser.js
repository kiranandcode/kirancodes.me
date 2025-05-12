/**
 * D3 Graph Timeline Visualizer
 * Creates an interactive visualization of graph data over time
 * with support for hierarchical and force-directed layouts
 * 
 * @param {string} containerId - ID of container element to place the visualization
 * @param {string} dataSource - URL or filename of JSON data source
 * @param {object} options - Optional configuration settings
 */
function plotTimeline(containerId, dataSource, options = {}) {
  // Default options
  const config = {
    width: options.width || 600,
    height: options.height || 400,
    colorMap: options.colorMap || {
      'can_state': '#0000FF',
      'not_ready': '#FAA33A',
      'proved': '#9CEC8B',
      'can_prove': '#A3D6FF',
      'defined': '#B0ECA3',
      'fully_proved': '#1CAC78'
    },
    initialLayout: options.initialLayout || 'force',
    animationDuration: options.animationDuration || 2000
  };

  // Create container for visualization
  const container = d3.select(`#${containerId}`)
    .style("position", "relative")
    .style("width", `${config.width}px`)
    .style("height", `${config.height + 100}px`) // Extra height for controls
    .style("overflow", "hidden")
    .style("border", "1px solid #ddd")
    .style("border-radius", "8px")
    .style("box-shadow", "0 2px 10px rgba(0,0,0,0.1)")
    .style("font-family", "Arial, sans-serif");

  // Create initial loading container with play button
  const loadingContainer = container.append("div")
    .attr("class", "loading-container")
    .style("position", "absolute")
    .style("top", "0")
    .style("left", "0")
    .style("width", "100%")
    .style("height", "100%")
    .style("display", "flex")
    .style("flex-direction", "column")
    .style("justify-content", "center")
    .style("align-items", "center")
    .style("background", "rgba(255,255,255,0.9)")
    .style("z-index", "10");

  // Add initial play button
  const initialPlayButton = loadingContainer.append("button")
    .attr("class", "initial-play-button")
    .text("▶ Load and Play Timeline")
    .style("padding", "12px 24px")
    .style("font-size", "16px")
    .style("border-radius", "6px")
    .style("border", "1px solid #007bff")
    .style("background", "#007bff")
    .style("color", "white")
    .style("cursor", "pointer")
    .style("box-shadow", "0 2px 5px rgba(0,0,0,0.2)")
    .style("transition", "all 0.2s ease");

  // Add hover effect
  initialPlayButton
    .on("mouseover", function() {
      d3.select(this)
        .style("background", "#0069d9")
        .style("box-shadow", "0 3px 7px rgba(0,0,0,0.3)");
    })
    .on("mouseout", function() {
      d3.select(this)
        .style("background", "#007bff")
        .style("box-shadow", "0 2px 5px rgba(0,0,0,0.2)");
    });

  // Create spinner (hidden initially)
  const spinner = loadingContainer.append("div")
    .attr("class", "spinner")
    .style("display", "none")
    .style("margin-top", "20px")
    .style("width", "50px")
    .style("height", "50px")
    .style("border", "5px solid rgba(0, 123, 255, 0.2)")
    .style("border-radius", "50%")
    .style("border-top-color", "#007bff")
    .style("animation", "spinner 1s linear infinite");

  // Add spinner animation
  const style = document.createElement('style');
  style.textContent = `
    @keyframes spinner {
      to { transform: rotate(360deg); }
    }
  `;
  document.head.appendChild(style);

  // Add loading text (hidden initially)
  const loadingText = loadingContainer.append("div")
    .attr("class", "loading-text")
    .text("Loading data...")
    .style("display", "none")
    .style("margin-top", "15px")
    .style("font-size", "14px")
    .style("color", "#666");

  // Create container for visualization controls (hidden initially)
  const controlsDiv = container.append("div")
    .attr("class", "controls")
    .style("position", "absolute")
    .style("bottom", "0")
    .style("left", "0")
    .style("right", "0")
    // .style("height", "80px")
    .style("background", "rgba(255,255,255,0.9)")
    .style("padding", "10px")
    .style("border-top", "1px solid #ddd")
    .style("z-index", "5")
    .style("display", "none");

  const legendContainer = container.append("div")
    .attr("class", "legend")
    .style("position", "absolute")
    .style("top", "0")
    .style("right", "0")
    // .style("height", "80px")
    .style("background", "rgba(255,255,255,0.9)")
    .style("padding", "10px")
    // .style("border-top", "1px solid #ddd")
    .style("z-index", "5")
    .style("display", "none");

    legendContainer.selectAll("div.legend-item")
        .data(Object.entries(config.colorMap))
        .enter()
        .append("div")
          .attr("class", "legend-item")
          .style("display", "flex")
          .style("align-items", "center")
          .style("gap", "6px")
          .style("margin-bottom", "4px")
        .each(function([key, color]) {
    const item = d3.select(this);
    item.append("div")
      .attr("class", "legend-color")
      .style("width", "12px")
      .style("height", "12px")
      .style("border", "1px solid #444")
      .style("background-color", color);
    
      item.append("span").text(key);
        });

  // Add tooltip div
  const tooltip = container.append("div")
    .attr("class", "tooltip")
    .style("position", "absolute")
    .style("display", "none")
    .style("background", "white")
    .style("border", "1px solid #ddd")
    .style("border-radius", "4px")
    .style("padding", "8px")
    .style("max-width", "250px")
    .style("max-height", "150px")
    .style("overflow", "auto")
    .style("z-index", "10")
    .style("pointer-events", "none")
    .style("font-size", "12px")
    .style("box-shadow", "0 2px 5px rgba(0,0,0,0.2)");

  // Create SVG with zoom functionality (hidden initially)
  const svg = container.append("svg")
    .attr("width", config.width)
    .attr("height", config.height)
    .attr("viewBox", [0, 0, config.width, config.height])
    .style("display", "none");

  // Add zoom capabilities
  const g = svg.append("g");

  // Store current transform to maintain position between transitions
  let currentTransform = d3.zoomIdentity;

  const zoom = d3.zoom()
    .scaleExtent([0.1, 5])
    .on("zoom", (event) => {
      currentTransform = event.transform;
      g.attr("transform", currentTransform);
    });

  svg.call(zoom);

  // Variables to track state
  let currentLayout = config.initialLayout;
  let currentIndex = 0;
  let currentData = null;
  let simulation = null;
  let nodePositions = new Map();
  let commits = [];
  let dates = [];
  
  // Add date display
  const dateDisplay = controlsDiv.append("div")
    .style("margin-bottom", "8px")
    .style("font-weight", "bold")
    .style("font-size", "14px");

  // Create slider container
  const sliderContainer = controlsDiv.append("div")
    .style("position", "relative")
    .style("height", "20px")
    .style("margin", "10px 0");

  // Add slider (will be configured once data is loaded)
  const slider = sliderContainer.append("input")
    .attr("type", "range")
    .style("width", "100%");
    
  // Add marker container 
  const markerContainer = sliderContainer.append("div")
    .style("position", "absolute")
    .style("top", "15px")
    .style("left", "0")
    .style("right", "0")
    .style("height", "10px");

  // Create layout toggle and controls container
  const buttonContainer = controlsDiv.append("div")
    .style("display", "flex")
    .style("justify-content", "space-between")
    .style("margin-top", "10px");

  // Left controls
  const leftControls = buttonContainer.append("div");
  
  // Add play button for animation
  const playButton = leftControls.append("button")
    .text("▶ Play")
    .style("margin-right", "5px")
    .style("padding", "3px 8px")
    .style("border-radius", "3px")
    .style("border", "1px solid #ccc")
    .style("background", "#f8f8f8")
    .style("cursor", "pointer");

  // Add layout toggle button
  const layoutToggle = leftControls.append("button")
    .text(currentLayout === "hierarchical" ? "Switch to Force" : "Switch to Tree")
    .style("margin-right", "5px")
    .style("padding", "3px 8px")
    .style("border-radius", "3px")
    .style("border", "1px solid #ccc")
    .style("background", "#f8f8f8")
    .style("cursor", "pointer");

  // Right controls
  const rightControls = buttonContainer.append("div");
  
  // Add zoom controls
  rightControls.append("button")
    .text("Zoom In")
    .style("margin-right", "5px")
    .style("padding", "3px 8px")
    .style("border-radius", "3px")
    .style("border", "1px solid #ccc")
    .style("background", "#f8f8f8")
    .style("cursor", "pointer")
    .on("click", () => {
      svg.transition().duration(750).call(zoom.scaleBy, 1.3);
    });

  rightControls.append("button")
    .text("Zoom Out")
    .style("margin-right", "5px")
    .style("padding", "3px 8px")
    .style("border-radius", "3px")
    .style("border", "1px solid #ccc")
    .style("background", "#f8f8f8")
    .style("cursor", "pointer")
    .on("click", () => {
      svg.transition().duration(750).call(zoom.scaleBy, 0.7);
    });

  rightControls.append("button")
    .text("Reset")
    .style("padding", "3px 8px")
    .style("border-radius", "3px")
    .style("border", "1px solid #ccc")
    .style("background", "#f8f8f8")
    .style("cursor", "pointer")
    .on("click", () => {
      currentTransform = d3.zoomIdentity;
      svg.transition().duration(750).call(zoom.transform, currentTransform);
    });

  // Function to get color based on node status
  function getColor(d) {
    if (d.node_fully_proved) return config.colorMap['fully_proved'];
    if (d.node_proved) return config.colorMap['proved'];
    if (d.node_can_prove) return config.colorMap['can_prove'];
    if (d.node_can_state) return config.colorMap['can_state'];
    return config.colorMap['not_ready'];
  }

  // Build hierarchy from nodes
  function buildHierarchy(nodes) {
    const idMap = new Map(nodes.map(d => [d.id, d]));
    const safeNodes = [];
    const seen = new Set();
    
    // First pass: Create basic nodes with direct dependencies
    for (const node of nodes) {
      if (!seen.has(node.id)) {
        safeNodes.push({
          ...node,
          parentIds: node.node_deps.filter(dep => dep !== node.id && idMap.has(dep)),
          // Store original dependencies for drawing edges later
          originalParentIds: node.node_deps.filter(dep => dep !== node.id && idMap.has(dep))
        });
        seen.add(node.id);
      }
    }
    
    // Compute transitive reduction for layout purposes
    const transitiveReduction = new Map();
    
    // Initialize with direct dependencies
    safeNodes.forEach(node => {
      transitiveReduction.set(node.id, new Set(node.parentIds));
    });
    
    // For each node, find indirect paths and remove redundant direct edges
    safeNodes.forEach(node => {
      const queue = [...node.parentIds];
      const visited = new Set();
      const indirectParents = new Set();
      
      while (queue.length > 0) {
        const parentId = queue.shift();
        
        if (visited.has(parentId)) continue;
        visited.add(parentId);
        
        // For transitive reduction, we want to track indirect ancestors
        const parent = safeNodes.find(n => n.id === parentId);
        if (parent) {
          parent.parentIds.forEach(grandparentId => {
            if (grandparentId !== node.id) { // Avoid cycles
              indirectParents.add(grandparentId);
              queue.push(grandparentId);
            }
          });
        }
      }
      
      // Remove redundant direct edges (if A→B→C, remove A→C)
      const reducedParents = node.parentIds.filter(parentId => !indirectParents.has(parentId));
      transitiveReduction.set(node.id, new Set(reducedParents));
    });
    
    // Update parentIds for layout purposes only
    safeNodes.forEach(node => {
      node.parentIds = Array.from(transitiveReduction.get(node.id) || []);
    });
    
    return safeNodes;
  }

  // Toggle layout and update visualization
  layoutToggle.on("click", function() {
    currentLayout = currentLayout === "hierarchical" ? "force" : "hierarchical";
    d3.select(this).text(currentLayout === "hierarchical" ? "Switch to Force" : "Switch to Tree");
    
    // Re-render with current data
    if (currentData) {
      animateToCommit(currentData, false);
    }
  });

  // Function to apply force-directed layout
  function applyForceLayout(nodes, links, nodeById) {
    // Stop any existing simulation
    if (simulation) simulation.stop();
    
    // Create force simulation
    simulation = d3.forceSimulation()
      .force("link", d3.forceLink().id(d => d.data.id).distance(80))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(config.width / 2, config.height / 2))
      .force("x", d3.forceX(config.width / 2).strength(0.05))
      .force("y", d3.forceY(config.height / 2).strength(0.05))
      .force("collision", d3.forceCollide().radius(40));
      
    // Extract node and link data for simulation
    const simNodes = Array.from(nodeById.values()).map(d => ({
      id: d.data.id,
      data: d.data,
      // Use existing position if available
      x: nodePositions.has(d.data.id) ? nodePositions.get(d.data.id).x : config.width / 2 + (Math.random() - 0.5) * 100,
      y: nodePositions.has(d.data.id) ? nodePositions.get(d.data.id).y : config.height / 2 + (Math.random() - 0.5) * 100
    }));
    
    const simLinks = links.map(l => ({
      source: l.source.data.id,
      target: l.target.data.id
    }));
    
    // Update simulation with new data
    simulation.nodes(simNodes);
    simulation.force("link").links(simLinks);
    
    // Run simulation with initial alpha decay
    simulation.alpha(0.3).restart();
    
    // Update positions during simulation
    simulation.on("tick", () => {
      g.selectAll("g.node")
        .attr("transform", d => {
          const simNode = simNodes.find(n => n.id === d.data.id);
          if (simNode) {
            // Update stored positions
            nodePositions.set(d.data.id, { x: simNode.x, y: simNode.y });
            return `translate(${simNode.x},${simNode.y})`;
          }
          return `translate(${d.x},${d.y})`;
        });
        
      g.selectAll("path.link")
        .attr("d", d => {
          const sourceNode = simNodes.find(n => n.id === d.source.data.id);
          const targetNode = simNodes.find(n => n.id === d.target.data.id);
          if (sourceNode && targetNode) {
            return `M${sourceNode.x},${sourceNode.y}L${targetNode.x},${targetNode.y}`;
          }
          return `M${d.source.x},${d.source.y}L${d.target.x},${d.target.y}`;
        });
    });
    
    // Stop simulation after a while to save resources
    setTimeout(() => {
      simulation.alpha(0).stop();
    }, 3000);
  }

  // Function to animate between two states of the graph
  function animateToCommit(rawNodes, isFirstLoad = true) {
    // Process nodes differently based on layout type
    const nodes = buildHierarchy(rawNodes);
    const nodeById = new Map();
    
    // Compute differences between old and new data
    const oldNodeIds = currentData ? new Set(currentData.map(d => d.id)) : new Set();
    const newNodeIds = new Set(rawNodes.map(d => d.id));
    
    // Track added and removed nodes
    const addedNodes = [...newNodeIds].filter(id => !oldNodeIds.has(id));
    const removedNodes = [...oldNodeIds].filter(id => !newNodeIds.has(id));
    
    // If changes are very significant, consider a full relayout
    const changeRatio = (addedNodes.length + removedNodes.length) / Math.max(oldNodeIds.size, newNodeIds.size, 1);
    if (changeRatio > 0.5) {
      nodePositions.clear();
    }

    // Apply layout based on current selection
    if (currentLayout === "hierarchical") {
      const rootNodes = nodes.filter(d => d.parentIds.length === 0);
      let yOffset = 50;
      
      // Layout tree with position memory
      rootNodes.forEach((root, i) => {
        const tree = d3.tree().nodeSize([40, 80]);
        const stratifyRoot = d3.hierarchy(root, d => nodes.filter(n => n.parentIds.includes(d.id)));
        
        // Apply tree layout
        const tData = tree(stratifyRoot);
        
        // Preserve positions for existing nodes
        tData.each(d => {
          const nodeId = d.data.id;
          
          // If we have a previous position for this node, use it
          if (nodePositions.has(nodeId)) {
            const prevPos = nodePositions.get(nodeId);
            // Apply a small movement towards the new position for stability
            d.x = prevPos.x * 0.8 + d.x * 0.2;
            d.y = prevPos.y * 0.8 + (d.y + yOffset) * 0.2;
          } else {
            // For new nodes, use the calculated position
            d.y += yOffset;
          }
          
          // Store current position for future use
          nodePositions.set(nodeId, { x: d.x, y: d.y });
          nodeById.set(nodeId, d);
        });

        yOffset += tData.height * 80 + 80;
      });
    } else {
      // Generate hierarchical structure first to establish parent-child relationships
      const rootNodes = nodes.filter(d => d.parentIds.length === 0);
      rootNodes.forEach((root, i) => {
        const stratifyRoot = d3.hierarchy(root, d => nodes.filter(n => n.parentIds.includes(d.id)));
        stratifyRoot.each(d => {
          nodeById.set(d.data.id, d);
        });
      });
      
      // For non-root nodes that weren't added yet
      nodes.forEach(node => {
        if (!nodeById.has(node.id)) {
          const newNode = d3.hierarchy(node);
          nodeById.set(node.id, newNode);
        }
      });
    }

    // Create links between nodes (using originalParentIds for drawing all edges)
    const links = [];
    nodeById.forEach((node, id) => {
      const src = node;
      // Use originalParentIds to draw all direct edges
      const targetIds = node.data.originalParentIds || node.data.parentIds;
      targetIds.forEach(pid => {
        if (nodeById.has(pid)) {
          links.push({ source: nodeById.get(pid), target: src });
        }
      });
    });

    // Update links with animation
    const link = g.selectAll("path.link")
      .data(links, d => `${d.source.data.id}-${d.target.data.id}`);
      
    // Exit old links
    link.exit()
      .transition()
      .duration(500)
      .style("opacity", 0)
      .remove();
      
    // Enter new links
    const linkEnter = link.enter()
      .append("path")
      .attr("class", "link")
      .attr("stroke", "#999")
      .attr("stroke-width", 1.5)
      .attr("fill", "none")
      .style("opacity", 0)
      .attr("d", d => {
        const sx = d.source.x || config.width/2;
        const sy = d.source.y || config.height/2;
        const tx = d.target.x || config.width/2;
        const ty = d.target.y || config.height/2;
        return `M${sx},${sy}L${tx},${ty}`;
      });
      
    // Update with transition
    linkEnter.transition()
      .duration(500)
      .style("opacity", 0.6);
      
    link.transition()
      .duration(750)
      .attr("d", d => {
        const sx = d.source.x || config.width/2;
        const sy = d.source.y || config.height/2;
        const tx = d.target.x || config.width/2;
        const ty = d.target.y || config.height/2;
        return `M${sx},${sy}L${tx},${ty}`;
      });

    // Update nodes with animation
    const node = g.selectAll("g.node")
      .data(Array.from(nodeById.values()), d => d.data.id);
      
    // Exit old nodes
    node.exit()
      .transition()
      .duration(500)
      .style("opacity", 0)
      .remove();
      
    // Enter new nodes
    const nodeEnter = node.enter()
      .append("g")
      .attr("class", "node")
      .attr("transform", d => {
        // Use stored position for existing nodes or place new nodes nearby
        const prevNode = nodePositions.get(d.data.id);
        if (prevNode) {
          return `translate(${prevNode.x},${prevNode.y})`;
        } else {
          return `translate(${config.width/2 + (Math.random() - 0.5) * 50},${config.height/2 + (Math.random() - 0.5) * 50})`;
        }
      })
      .style("opacity", 0)
      .on("mouseover", (event, d) => {
        tooltip.style("display", "block")
          .html(`<strong>${d.data.node_full_title}</strong><hr>${d.data.node_text_content}`)
          .style("left", (event.clientX - container.node().getBoundingClientRect().left + 10) + "px")
          .style("top", (event.clientY - container.node().getBoundingClientRect().top - 30) + "px");
      })
      .on("mouseout", () => tooltip.style("display", "none"));
      
    // Add circles to nodes
    nodeEnter.append("circle")
      .attr("r", 15)
      .attr("fill", d => getColor(d.data))
      .attr("stroke", "#000")
      .attr("stroke-width", 1);
      
    // Add text labels (smaller and constrained)
    nodeEnter.append("text")
      .attr("x", 20)
      .attr("y", 5)
      .attr("text-anchor", "start")
      .text(d => {
        // Truncate long titles
        const title = d.data.node_full_title;
        return title.length > 20 ? title.substring(0, 18) + '...' : title;
      })
      .style("font-size", "10px");
      
    // Fade in new nodes
    nodeEnter.transition()
      .duration(500)
      .style("opacity", 1);
      
    // Update existing nodes with eased transition
    node.transition()
      .duration(750)
      .attr("transform", d => {
        const x = d.x || config.width/2;
        const y = d.y || config.height/2;
        return `translate(${x},${y})`;
      })
      .select("circle")
      .attr("fill", d => getColor(d.data));
      
    // Apply different transitions based on whether nodes are new/changed
    node.select("circle")
      .transition()
      .duration(750)
      .attr("fill", d => getColor(d.data))
      .attr("r", d => {
        // Highlight new nodes
        const isNew = addedNodes.includes(d.data.id);
        return isNew ? 20 : 15;
      })
      .transition()
      .duration(500)
      .attr("r", 15);
      
    // Only center the graph on first load
    if (isFirstLoad) {
      setTimeout(() => {
        const bounds = g.node().getBBox();
        const centerX = config.width / 2 - (bounds.x + bounds.width / 2);
        const centerY = config.height / 2 - (bounds.y + bounds.height / 2);
        
        g.transition()
          .duration(750)
          .call(
            zoom.transform,
            d3.zoomIdentity
              .translate(centerX, centerY)
              .scale(0.7)
          );
      }, 100);
    }
    
    // If using force layout, apply it
    if (currentLayout === "force") {
      applyForceLayout(nodes, links, nodeById);
    }
    
    // Store current data for future animations
    currentData = rawNodes;
  }


  // Function to fetch and process data
  function loadData() {
    // Show loading spinner and hide play button
    initialPlayButton.style("display", "none");
    spinner.style("display", "block");
    loadingText.style("display", "block");
    
    fetch(dataSource)
      .then(r => r.json())
      .then(data => {
        // Hide loading elements and show visualization components
        loadingContainer.style("display", "none");
        svg.style("display", "block");
        controlsDiv.style("display", "block");
        legendContainer.style("display","block");
        
        commits = Object.entries(data).sort((a, b) => new Date(a[1].date) - new Date(b[1].date));
        
        // Extract all dates and create a time scale
        dates = commits.map(c => new Date(c[1].date));
        const minDate = d3.min(dates);
        const maxDate = d3.max(dates);
        
        // Configure slider
        slider
          .attr("min", minDate.getTime())
          .attr("max", maxDate.getTime())
          .attr("step", 86400000) // One day in milliseconds
          .attr("value", minDate.getTime())
          .on("input", function() {
            const selectedDate = new Date(+this.value);
            
            // Find the closest commit index to the selected date
            const closestIndex = d3.bisectLeft(dates, selectedDate);
            const newIndex = Math.min(closestIndex, commits.length - 1);
            
            if (newIndex !== currentIndex) {
              currentIndex = newIndex;
              // Pass false to maintain zoom and position
              animateToCommit(commits[currentIndex][1].graph, false);
            }
            
            // Update the date display
            updateDateDisplay(selectedDate);
          });
        
      // Add markers for each commit
      dates.forEach((date, i) => {
        const percentage = (date - minDate) / (maxDate - minDate) * 100;
        
        markerContainer.append("div")
          .style("position", "absolute")
          .style("left", `${percentage}%`)
          .style("width", "2px")
          .style("height", "8px")
          .style("background-color", "#333")
          .style("transform", "translateX(-50%)")
          .on("mouseover", function() {
            d3.select(this).style("height", "12px").style("background-color", "#007bff");
            tooltip.style("display", "block")
              .html(`Commit: ${commits[i][0].substring(0, 8)}<br>Date: ${date.toLocaleDateString()}`)
              .style("left", `${percentage}%`)
              .style("top", "30px");
          })
          .on("mouseout", function() {
            d3.select(this).style("height", "8px").style("background-color", "#333");
            tooltip.style("display", "none");
          })
          .on("click", function() {
            slider.property("value", date.getTime());
            currentIndex = i;
            animateToCommit(commits[i][1].graph, false);
            updateDateDisplay(date);
          });
      });
      
      // Set up play button functionality
      playButton.on("click", function() {
        const isPlaying = d3.select(this).text() === "⏸ Pause";
        
        if (isPlaying) {
          d3.select(this).text("▶ Play");
          if (window.animationTimer) {
            window.animationTimer.stop();
          }
        } else {
          d3.select(this).text("⏸ Pause");
          
          let nextIndex = currentIndex + 1;
          if (nextIndex >= commits.length) {
            nextIndex = 0;
            slider.property("value", minDate.getTime());
            updateDateDisplay(minDate);
          }
          
          window.animationTimer = d3.interval(() => {
            if (nextIndex < commits.length) {
              currentIndex = nextIndex;
              const nextDate = dates[nextIndex];
              slider.property("value", nextDate.getTime());
              // Pass false to prevent zooming out on each step
              animateToCommit(commits[nextIndex][1].graph, false);
              updateDateDisplay(nextDate);
              nextIndex++;
            } else {
              // Reset to beginning when reaching the end
              nextIndex = 0;
              currentIndex = 0;
              slider.property("value", minDate.getTime());
              // Pass false to prevent zooming out
              animateToCommit(commits[0][1].graph, false);
              updateDateDisplay(minDate);
            }
          }, config.animationDuration);
        }
      });
      
      // Update date display function
      function updateDateDisplay(date) {
        const commitId = commits[currentIndex][0].substring(0, 8);
        dateDisplay.text(`${date.toLocaleDateString()} - ${commitId}`);
      }
      
      // Initialize with the first date
      updateDateDisplay(minDate);
      
      // Initialize with first commit data
      animateToCommit(commits[0][1].graph);

      })
          .catch(error => {
      console.error("Error loading data:", error);
      container.append("div")
        .style("color", "red")
        .style("padding", "20px")
        .text("Error loading data. Please check the console for details.");
    });;

      
  }

    initialPlayButton.on("click", function() {loadData();});

  // Return API for external control
  return {
    resize(width, height) {
      container.style("width", `${width}px`);
      container.style("height", `${height + 100}px`);
      svg.attr("width", width).attr("height", height);
    },
    setLayout(layout) {
      if (layout === "hierarchical" || layout === "force") {
        currentLayout = layout;
        layoutToggle.text(currentLayout === "hierarchical" ? "Switch to Force" : "Switch to Tree");
        if (currentData) {
          animateToCommit(currentData, false);
        }
      }
    }
  };    


}


// Helper function to create and initialize the visualization
function createGraphTimeline(elementId, dataName, options = {}) {
  // Create container if it doesn't exist
  if (!document.getElementById(elementId)) {
    const container = document.createElement('div');
    container.id = elementId;
    document.currentScript.parentNode.insertBefore(container, document.currentScript.nextSibling);
  }

  // Default URL pattern, can be overridden with options
  const dataUrl = options.dataUrl || `https://raw.githubusercontent.com/kiranandcode/lean4-blueprint-extractor/refs/heads/main/data/${dataName}.json`;
  
  // Initialize the visualization
  return plotTimeline(elementId, dataUrl, options);
}

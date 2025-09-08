/**
 * GdkPixbuf WASM Benchmark Suite
 * Copyright 2025 Superstruct Ltd, New Zealand
 * Licensed under LGPL-2.1-or-later
 */

class GdkPixbufBenchmarkSuite {
    constructor() {
        this.benchmarks = [];
        this.results = [];
        this.gdkPixbuf = null;
        this.testImages = new Map();
    }

    /**
     * Add a benchmark test
     */
    addBenchmark(name, benchmarkFunction, options = {}) {
        this.benchmarks.push({
            name,
            function: benchmarkFunction,
            iterations: options.iterations || 10,
            warmupIterations: options.warmupIterations || 2,
            category: options.category || 'general'
        });
    }

    /**
     * Run a single benchmark with multiple iterations
     */
    async runBenchmark(benchmark) {
        console.log(`Running benchmark: ${benchmark.name}`);
        
        const results = {
            name: benchmark.name,
            category: benchmark.category,
            iterations: benchmark.iterations,
            times: [],
            stats: {}
        };

        // Warmup runs
        for (let i = 0; i < benchmark.warmupIterations; i++) {
            try {
                await benchmark.function();
            } catch (error) {
                console.warn(`Warmup iteration ${i} failed:`, error);
            }
        }

        // Actual benchmark runs
        for (let i = 0; i < benchmark.iterations; i++) {
            const startTime = performance.now();
            
            try {
                await benchmark.function();
                const endTime = performance.now();
                const duration = endTime - startTime;
                results.times.push(duration);
            } catch (error) {
                console.error(`Benchmark iteration ${i} failed:`, error);
                results.times.push(null); // Mark failed iteration
            }

            // Small delay to prevent UI blocking
            await new Promise(resolve => setTimeout(resolve, 1));
        }

        // Calculate statistics
        const validTimes = results.times.filter(t => t !== null);
        if (validTimes.length > 0) {
            results.stats = this.calculateStats(validTimes);
        }

        this.results.push(results);
        return results;
    }

    /**
     * Calculate statistical measures
     */
    calculateStats(times) {
        const sorted = [...times].sort((a, b) => a - b);
        const sum = times.reduce((a, b) => a + b, 0);
        const mean = sum / times.length;
        
        const variance = times.reduce((acc, time) => {
            return acc + Math.pow(time - mean, 2);
        }, 0) / times.length;
        
        const stdDev = Math.sqrt(variance);
        
        return {
            min: Math.min(...times),
            max: Math.max(...times),
            mean: mean,
            median: sorted[Math.floor(sorted.length / 2)],
            p95: sorted[Math.floor(sorted.length * 0.95)],
            p99: sorted[Math.floor(sorted.length * 0.99)],
            stdDev: stdDev,
            coefficient: stdDev / mean // Coefficient of variation
        };
    }

    /**
     * Generate synthetic test images for benchmarking
     */
    async generateBenchmarkImages() {
        const sizes = [
            { name: 'tiny', width: 64, height: 64 },
            { name: 'small', width: 256, height: 256 },
            { name: 'medium', width: 512, height: 512 },
            { name: 'large', width: 1024, height: 1024 },
            { name: 'xlarge', width: 2048, height: 2048 },
            { name: 'hd', width: 1920, height: 1080 },
            { name: '4k', width: 3840, height: 2160 }
        ];

        for (const size of sizes) {
            // Create solid color image
            const solidCanvas = this.createTestCanvas(size.width, size.height, 'solid');
            await this.addCanvasAsImage(`${size.name}_solid`, solidCanvas, ['png', 'jpeg']);

            // Create gradient image
            const gradientCanvas = this.createTestCanvas(size.width, size.height, 'gradient');
            await this.addCanvasAsImage(`${size.name}_gradient`, gradientCanvas, ['png', 'jpeg']);

            // Create noise image (more complex)
            const noiseCanvas = this.createTestCanvas(size.width, size.height, 'noise');
            await this.addCanvasAsImage(`${size.name}_noise`, noiseCanvas, ['png']);
        }

        console.log(`Generated ${this.testImages.size} benchmark images`);
    }

    /**
     * Create test canvas with different patterns
     */
    createTestCanvas(width, height, pattern) {
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');

        switch (pattern) {
            case 'solid':
                ctx.fillStyle = '#ff6b6b';
                ctx.fillRect(0, 0, width, height);
                break;
                
            case 'gradient':
                const gradient = ctx.createLinearGradient(0, 0, width, height);
                gradient.addColorStop(0, '#ff6b6b');
                gradient.addColorStop(0.25, '#4ecdc4');
                gradient.addColorStop(0.5, '#45b7d1');
                gradient.addColorStop(0.75, '#96ceb4');
                gradient.addColorStop(1, '#feca57');
                ctx.fillStyle = gradient;
                ctx.fillRect(0, 0, width, height);
                break;
                
            case 'noise':
                const imageData = ctx.createImageData(width, height);
                const data = imageData.data;
                for (let i = 0; i < data.length; i += 4) {
                    data[i] = Math.random() * 255;     // Red
                    data[i + 1] = Math.random() * 255; // Green
                    data[i + 2] = Math.random() * 255; // Blue
                    data[i + 3] = 255;                 // Alpha
                }
                ctx.putImageData(imageData, 0, 0);
                break;
        }

        return canvas;
    }

    /**
     * Convert canvas to various image formats
     */
    async addCanvasAsImage(name, canvas, formats) {
        for (const format of formats) {
            try {
                const mimeType = `image/${format}`;
                const quality = format === 'jpeg' ? 0.9 : undefined;
                
                const blob = await new Promise(resolve => {
                    canvas.toBlob(resolve, mimeType, quality);
                });
                
                const arrayBuffer = await blob.arrayBuffer();
                const uint8Array = new Uint8Array(arrayBuffer);
                
                this.testImages.set(`${name}.${format}`, {
                    data: uint8Array,
                    width: canvas.width,
                    height: canvas.height,
                    format: format,
                    size: uint8Array.length
                });
            } catch (error) {
                console.warn(`Failed to create ${name}.${format}:`, error);
            }
        }
    }

    /**
     * Run all benchmarks
     */
    async runAllBenchmarks() {
        console.log('Starting GdkPixbuf WASM benchmark suite...');
        
        // Generate test images
        await this.generateBenchmarkImages();

        this.results = [];
        const startTime = performance.now();

        for (const benchmark of this.benchmarks) {
            const result = await this.runBenchmark(benchmark);
            this.displayBenchmarkResult(result);
            
            // Allow UI to update
            await new Promise(resolve => setTimeout(resolve, 100));
        }

        const totalTime = performance.now() - startTime;
        console.log(`All benchmarks completed in ${totalTime.toFixed(2)}ms`);
        
        this.generateReport();
        return this.results;
    }

    /**
     * Display benchmark result
     */
    displayBenchmarkResult(result) {
        const resultsDiv = document.getElementById('benchmarkResults');
        if (!resultsDiv) return;

        const resultDiv = document.createElement('div');
        resultDiv.className = 'benchmark-result';
        
        const stats = result.stats;
        const validIterations = result.times.filter(t => t !== null).length;

        resultDiv.innerHTML = `
            <h4>${result.name}</h4>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin: 10px 0;">
                <div><strong>Iterations:</strong> ${validIterations}/${result.iterations}</div>
                <div><strong>Mean:</strong> ${stats.mean?.toFixed(2) || 'N/A'}ms</div>
                <div><strong>Median:</strong> ${stats.median?.toFixed(2) || 'N/A'}ms</div>
                <div><strong>Min:</strong> ${stats.min?.toFixed(2) || 'N/A'}ms</div>
                <div><strong>Max:</strong> ${stats.max?.toFixed(2) || 'N/A'}ms</div>
                <div><strong>P95:</strong> ${stats.p95?.toFixed(2) || 'N/A'}ms</div>
                <div><strong>StdDev:</strong> ${stats.stdDev?.toFixed(2) || 'N/A'}ms</div>
                <div><strong>CV:</strong> ${((stats.coefficient || 0) * 100).toFixed(1)}%</div>
            </div>
        `;

        resultsDiv.appendChild(resultDiv);
    }

    /**
     * Generate comprehensive benchmark report
     */
    generateReport() {
        const report = {
            timestamp: new Date().toISOString(),
            userAgent: navigator.userAgent,
            platform: {
                hardwareConcurrency: navigator.hardwareConcurrency,
                memory: navigator.deviceMemory,
                connection: navigator.connection?.effectiveType
            },
            results: this.results.map(result => ({
                name: result.name,
                category: result.category,
                stats: result.stats,
                iterations: result.iterations,
                validRuns: result.times.filter(t => t !== null).length
            }))
        };

        // Display summary
        const summaryDiv = document.getElementById('benchmarkResults');
        if (summaryDiv) {
            const summary = document.createElement('div');
            summary.className = 'benchmark-result';
            summary.innerHTML = `
                <h3>Benchmark Summary</h3>
                <p><strong>Total Benchmarks:</strong> ${this.results.length}</p>
                <p><strong>Platform:</strong> ${navigator.platform}</p>
                <p><strong>CPU Cores:</strong> ${navigator.hardwareConcurrency || 'Unknown'}</p>
                <p><strong>Memory:</strong> ${navigator.deviceMemory || 'Unknown'}GB</p>
                <button onclick="downloadBenchmarkReport()">Download Detailed Report</button>
            `;
            summaryDiv.appendChild(summary);
        }

        // Make report available for download
        this.reportData = report;
        return report;
    }

    /**
     * Export benchmark results
     */
    exportResults() {
        if (!this.reportData) {
            console.error('No benchmark results to export');
            return;
        }

        const blob = new Blob([JSON.stringify(this.reportData, null, 2)], {
            type: 'application/json'
        });

        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `gdk-pixbuf-benchmark-${Date.now()}.json`;
        a.click();
        URL.revokeObjectURL(url);
    }
}

// Initialize benchmark suite
const benchmarkSuite = new GdkPixbufBenchmarkSuite();

// Image Loading Benchmarks
benchmarkSuite.addBenchmark('Small PNG Loading', async () => {
    const imageData = benchmarkSuite.testImages.get('small_solid.png');
    if (imageData && benchmarkSuite.gdkPixbuf) {
        return benchmarkSuite.gdkPixbuf.newFromData(imageData.data);
    }
}, { category: 'loading', iterations: 50 });

benchmarkSuite.addBenchmark('Medium JPEG Loading', async () => {
    const imageData = benchmarkSuite.testImages.get('medium_gradient.jpeg');
    if (imageData && benchmarkSuite.gdkPixbuf) {
        return benchmarkSuite.gdkPixbuf.newFromData(imageData.data);
    }
}, { category: 'loading', iterations: 20 });

benchmarkSuite.addBenchmark('Large PNG Loading', async () => {
    const imageData = benchmarkSuite.testImages.get('large_noise.png');
    if (imageData && benchmarkSuite.gdkPixbuf) {
        return benchmarkSuite.gdkPixbuf.newFromData(imageData.data);
    }
}, { category: 'loading', iterations: 10 });

// Scaling Benchmarks
benchmarkSuite.addBenchmark('Upscale Small Image 2x', async () => {
    const imageData = benchmarkSuite.testImages.get('small_gradient.png');
    if (imageData && benchmarkSuite.gdkPixbuf) {
        const pixbuf = benchmarkSuite.gdkPixbuf.newFromData(imageData.data);
        return benchmarkSuite.gdkPixbuf.scaleSimple(pixbuf, imageData.width * 2, imageData.height * 2);
    }
}, { category: 'scaling', iterations: 30 });

benchmarkSuite.addBenchmark('Downscale Large Image 0.5x', async () => {
    const imageData = benchmarkSuite.testImages.get('large_solid.png');
    if (imageData && benchmarkSuite.gdkPixbuf) {
        const pixbuf = benchmarkSuite.gdkPixbuf.newFromData(imageData.data);
        return benchmarkSuite.gdkPixbuf.scaleSimple(pixbuf, imageData.width / 2, imageData.height / 2);
    }
}, { category: 'scaling', iterations: 15 });

// Format Conversion Benchmarks
benchmarkSuite.addBenchmark('PNG to Canvas Conversion', async () => {
    const imageData = benchmarkSuite.testImages.get('medium_solid.png');
    if (imageData && benchmarkSuite.gdkPixbuf) {
        const pixbuf = benchmarkSuite.gdkPixbuf.newFromData(imageData.data);
        const canvas = document.createElement('canvas');
        canvas.width = imageData.width;
        canvas.height = imageData.height;
        return benchmarkSuite.gdkPixbuf.toCanvas(pixbuf, canvas);
    }
}, { category: 'conversion', iterations: 25 });

// Memory Stress Tests
benchmarkSuite.addBenchmark('Rapid Image Creation/Destruction', async () => {
    const imageData = benchmarkSuite.testImages.get('tiny_solid.png');
    if (imageData && benchmarkSuite.gdkPixbuf) {
        const pixbufs = [];
        
        // Create many images
        for (let i = 0; i < 100; i++) {
            pixbufs.push(benchmarkSuite.gdkPixbuf.newFromData(imageData.data));
        }
        
        // Destroy them
        for (const pixbuf of pixbufs) {
            if (pixbuf.dispose) {
                pixbuf.dispose();
            }
        }
    }
}, { category: 'memory', iterations: 10 });

// Batch Processing Benchmarks
benchmarkSuite.addBenchmark('Batch Image Processing', async () => {
    const images = [
        'tiny_solid.png',
        'small_gradient.png',
        'medium_noise.png'
    ];
    
    if (benchmarkSuite.gdkPixbuf) {
        const results = [];
        for (const imageName of images) {
            const imageData = benchmarkSuite.testImages.get(imageName);
            if (imageData) {
                const pixbuf = benchmarkSuite.gdkPixbuf.newFromData(imageData.data);
                const scaled = benchmarkSuite.gdkPixbuf.scaleSimple(pixbuf, 128, 128);
                results.push(scaled);
            }
        }
        return results;
    }
}, { category: 'batch', iterations: 20 });

// Make benchmark suite available globally
if (typeof window !== 'undefined') {
    window.benchmarkSuite = benchmarkSuite;
    window.downloadBenchmarkReport = () => benchmarkSuite.exportResults();
    window.runBenchmarks = () => benchmarkSuite.runAllBenchmarks();
}

// Export for Node.js if applicable
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GdkPixbufBenchmarkSuite;
}
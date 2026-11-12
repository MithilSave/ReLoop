# **Architectural Blueprint and Broader Technology Stack for the Circular Plastics Exchange Platform**

The transition toward a circular economy for plastics necessitates a robust, multi-tenant digital infrastructure capable of orchestrating the complex interactions between waste generators, collection logistics networks, and recycling facilities. While foundational prototypes often rely on generic frameworks—such as standard Flutter mobile applications, Firebase backend-as-a-service (BaaS), and unoptimized TensorFlow models—scaling a Circular Plastics Exchange demands a significantly broader and more sophisticated technology stack. In the context of a hypothetical polymer manufacturer seeking to trace mixed, unsorted waste from campuses and small businesses back into the recycling loop, the platform must process complex visual data, optimize combinatorial logistics, and integrate with macroeconomic environmental compliance frameworks. This report provides an exhaustive architectural blueprint for developing a high-performance, edge-AI-enabled, and cryptographically verifiable platform, transitioning from basic conceptual fits to an enterprise-grade technology stack.

## **1\. Edge-Optimized Computer Vision for Resin Identification**

The core technological expectation of the Circular Plastics Exchange is the accurate visual classification of plastic waste into specific Resin Identification Codes (RIC), primarily Polyethylene Terephthalate (PET \- 01), High-Density Polyethylene (HDPE \- 02), and Polypropylene (PP \- 05). Traditional visual identification systems rely on RGB color thresholding, which is predicated on the observation that opaque HDPE exhibits significantly higher red, green, and blue intensity values compared to transparent PET and PP1. However, deterministic color space mapping fails in real-world municipal waste streams characterized by dirt, physical deformation, varied ambient lighting, and occlusion. Consequently, the architecture must rely on Convolutional Neural Networks (CNNs) and transformer-based object detection models deployed directly on mobile edge devices, returning both classification labels and granular confidence scores.

### **1.1 Dataset Selection and Class Imbalance Mitigation**

The foundation of the classification model is the training dataset. The WaDaBa (Waste DataBase) dataset serves as the industry-standard benchmark for plastic resin classification2. WaDaBa contains approximately 4,000 high-resolution images acquired under varying conditions of lighting (fluorescent and LED), orientation, and physical deformation, including crushed, torn, and partially obscured containers2.  
However, WaDaBa suffers from severe class imbalance, accurately reflecting the statistical reality of municipal waste streams but presenting a hazard for machine learning convergence. PET comprises approximately 55% of the dataset, while PP and HDPE account for significantly smaller fractions, and other categories are barely represented2. To prevent a custom CNN from biasing toward the majority class and artificially inflating its accuracy by perpetually guessing PET, the training pipeline must implement synthetic oversampling and aggressive data augmentation. Techniques such as random zoom, horizontal and vertical flipping, contrast adjustment, and affine rotations up to 15 degrees are mandatory to expand the dataset to a robust training volume, effectively normalizing the distribution across the target RIC classes5.

### **1.2 Architectural Evaluation: CNNs vs. YOLO vs. Vision Transformers**

The selection of the neural network architecture involves balancing Mean Average Precision (mAP) against inference latency and memory footprint on mobile Neural Processing Units (NPUs) or standard mobile CPUs.  
Custom Convolutional Neural Networks built with TensorFlow and Keras offer a viable starting point, particularly when employing transfer learning on established backbones. MobileNetV2 remains a highly efficient feature extractor, utilizing depthwise separable convolutions to achieve up to 97.12% accuracy on the WaDaBa dataset5. MobileNetV3 introduces neural architecture search and hardware-aware squeeze-and-excitation modules, further reducing latency on mobile CPUs9. However, these are fundamentally image classification models; they assume the plastic item is perfectly centered and occupies the majority of the frame. In a user-facing mobile application, this is an unrealistic expectation, as waste generators often photograph cluttered scenes containing multiple mixed items.  
The "You Only Look Once" (YOLO) architecture is vastly superior for real-world waste detection because it simultaneously localizes objects via bounding boxes and classifies multiple items in a highly cluttered scene. The YOLOv11 iteration introduces an optimized accuracy-latency trade-off, pushing the boundaries of edge-based object detection10. On the WaDaBa dataset, the YOLO-11n (nano) variant achieves a benchmark accuracy of 0.9553 and a precision of 0.9803, with an inference time of merely 272 milliseconds per frame5. For applications requiring the strict minimization of false positives—which is crucial when matching waste to specific chemical recyclers who cannot tolerate contamination—YOLO-11m (medium) provides superior precision at the cost of higher computational latency5.  
Alternatively, hybrid architectures like MobileViT integrate the global attention mechanisms of Vision Transformers with the spatial inductive biases of CNNs11. While MobileViT outperforms comparable CNNs in certain MS COCO object detection metrics, the deployment of transformers on heterogeneous mobile hardware often results in unpredictable latency spikes compared to heavily optimized convolutional operators, rendering them less ideal for real-time mobile augmented reality applications11.

| Model Architecture | Parameter Size | WaDaBa Accuracy | Precision | Inference Latency (Mobile Edge) | Use Case Suitability |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Custom CNN (ResNet50) | \~25.6M | 65.20% | 65.43% | \>200 ms | Poor performance on imbalanced edge data; too heavy for mobile. |
| MobileNetV2 (Classification) | \~3.4M | 97.12% | 96.31% | \~40-80 ms | High accuracy for single, centered objects; lacks localization. |
| YOLO-11n (Detection) | \~2.6M | 95.53% | 98.03% | \~272 ms | Optimal for real-time multi-object detection and edge deployment. |
| YOLO-11m (Detection) | \~20.1M | 95.51% | 98.14% | \~5.9 s (CPU) | High precision, better suited for server-side batch processing. |
| MobileViT-XS | \~2.3M | Variable | Variable | \~188-500 ms | Strong accuracy, but suffers from mobile runtime heterogeneity. |

Given the requirement for real-time bounding box overlays and confidence scoring on mobile devices, deploying a quantized YOLO-11n model via TensorFlow Lite or ONNX Runtime is the optimal architectural choice, providing the necessary spatial localization that standard custom CNNs lack.

## **2\. Neural Network Quantization and Edge Deployment**

To deploy YOLO-11n or MobileNet architectures directly to mobile devices, the 32-bit floating-point (FP32) weights and activations must be quantized to 8-bit integers (INT8). This process reduces the model size by approximately 75%, vastly decreases memory bandwidth requirements, and dramatically accelerates matrix multiplication on mobile hardware, ensuring the application remains responsive and does not drain the device's battery13.

### **2.1 The Failure of Post-Training Quantization (PTQ)**

Standard Post-Training Quantization (PTQ) involves applying a calibration dataset to a frozen, pre-trained FP32 model to estimate the minimum and maximum ranges of its activations14. While PTQ is computationally inexpensive and requires no retraining, it fundamentally disrupts the accuracy of highly compact edge models. For instance, applying dynamic or static PTQ to MobileNetV3 architectures often fails catastrophically due to the model's reliance on the non-linear hard-swish activation function, which maps poorly to a linear INT8 grid16. Direct INT8 PTQ without architectural compensation can drop a network's accuracy by up to 25 percentage points, effectively rendering the waste classification useless17.

### **2.2 Implementing Quantization-Aware Training (QAT)**

To maintain high confidence scores, the AI pipeline must utilize Quantization-Aware Training (QAT). QAT injects "fake quantization" or "pseudo-quantization" nodes into the computation graph during the final epochs of the training process. These nodes simulate the quantization rounding and clipping errors during the forward pass, allowing the network to experience the noise of low-precision arithmetic14.  
Because the quantization operation is non-differentiable—acting as a step function with a gradient of zero—QAT employs a Straight-Through Estimator (STE) during the backward pass. The STE passes the gradients through the quantizer unchanged, updating the underlying FP32 weights17. By simulating this noise, QAT allows the network to self-adjust its weights to compensate for the upcoming precision loss, recovering the accuracy lost in PTQ and yielding an INT8 model that performs within 1% of the FP32 baseline while nearly doubling the inference frames per second (FPS)15.

## **3\. High-Performance Mobile Client Architecture**

The initial technical fit suggests rapid development of a cross-platform mobile app using Flutter. While Flutter is a highly capable UI toolkit, pushing real-time, high-framerate computer vision through its standard architecture introduces severe performance bottlenecks.

### **3.1 The Limitations of Standard Cross-Platform Bridges**

In a standard Flutter application, passing live camera frames to a local TensorFlow Lite model requires serializing the image bytes and passing them across asynchronous platform channels, or utilizing Dart Foreign Function Interfaces (FFI). While FFI is faster than platform channels, passing large multidimensional arrays (tensors) still incurs memory copying overhead that degrades inference latency, throttles the UI thread, and induces thermal throttling on the device19. Real-time waste detection requires analyzing 30 to 60 frames per second; any memory serialization pipeline will inevitably drop frames and result in a sluggish user experience.

### **3.2 Transitioning to React Native and C++ JSI Frame Processors**

To achieve sustained real-time plastic identification, the mobile architecture should pivot toward React Native, specifically leveraging the react-native-vision-camera library coupled with JavaScript Interface (JSI) C++ Frame Processors21.  
JSI entirely replaces the legacy asynchronous React Native bridge with direct, synchronous C++ bindings. When the mobile device's camera hardware captures a frame, the image data is never serialized to the JavaScript runtime. Instead, the native Worklet architecture passes a direct memory pointer of the hardware buffer to a customized C++ module20.  
This achieves absolute zero-copy memory access. On Android, the frame is accessed via the AHardwareBuffer API; on iOS, it is accessed via CVPixelBuffer22. The C++ backend, running the ONNX Runtime or TensorFlow Lite C++ APIs, reads the pixel data directly from the GPU or Image Signal Processor (ISP) memory without copying it into the CPU heap20. The synchronous Worklet executes the inference on a dedicated background thread, completely bypassing the JavaScript garbage collector. The C++ plugin then returns only the localized bounding box coordinates, string labels (e.g., "HDPE"), and confidence scores back to the JavaScript UI thread via JSI Host Objects20.  
This zero-copy architectural paradigm ensures that the mobile device's thermal limits are respected, and the user experiences a fluid augmented reality interface where bounding boxes seamlessly track physical plastic waste in real-time, providing immediate visual feedback to the waste generator.

## **4\. Backend Infrastructure and Multi-Tenant Security**

The initial proposal suggests utilizing Firebase for separate user role authentications and real-time pickup scheduling. However, Firebase's NoSQL document structure is fundamentally ill-suited for the complex, multi-actor supply chain tracking required by a Circular Plastics Exchange. Tracking a specific batch of waste from a generator, assigning it to a collector's optimized vehicle route, and subsequently transferring custody to a chemical recycler requires strict relational integrity (ACID compliance). Furthermore, executing complex geospatial queries—such as matching local collectors to generators within a specific radius—is highly inefficient and costly in standard NoSQL environments.  
The optimal infrastructure choice is PostgreSQL, utilizing a modern Backend-as-a-Service (BaaS) provider such as Supabase. PostgreSQL natively supports advanced spatial queries via the PostGIS extension and high-dimensional vector embeddings via pgvector, while the Supabase layer provides seamless integration for authentication and real-time WebSockets24.

### **4.1 Role-Based Access Control (RBAC) via Row Level Security (RLS)**

In a traditional centralized API architecture, the backend application server governs authorization logic. In the Supabase and PostgreSQL paradigm, authorization is pushed directly into the database kernel via Row Level Security (RLS)24. Every HTTP request from the mobile client is mapped to a Postgres role, and a JSON Web Token (JWT) containing the user's unique identifier and custom claims is injected directly into the database session24.  
This provides impenetrable, cryptographic data isolation for the three primary actors in the exchange:

* **Waste Generators:** RLS policies restrict generators so they can only SELECT, INSERT, and UPDATE waste listings where the generator\_id matches their own authenticated token. They cannot view or manipulate data belonging to other households or businesses27.  
* **Collectors:** Logistics operators require a different view. Their RLS policies allow them to SELECT listings within a specific geospatial radius (utilizing PostGIS ST\_DWithin functions) that are marked with a status of 'pending'. They are granted UPDATE privileges to change the status to 'accepted' or 'in\_transit', but the policy strictly prohibits them from altering the underlying material classification, weight, or generator details29.  
* **Recyclers:** Facility operators can only SELECT inbound shipments destined for their specific registered facility and UPDATE the final status to 'received' or 'recycled', effectively closing the loop27.

A critical performance optimization must be observed when implementing RLS. A naive policy execution forces the PostgreSQL query planner to evaluate the authentication function on every single row during a sequential scan, which drastically degrades performance as the exchange scales to thousands of concurrent users27. To resolve this, policies must be written using scalar subqueries. This syntax forces the Postgres optimizer to execute an initPlan, evaluating the function exactly once per statement and caching the result in memory, thereby preserving sub-millisecond query latency even when scanning millions of waste records27.

| Feature | Firebase (NoSQL) | Supabase / PostgreSQL (Relational) | Architectural Impact on Plastics Exchange |
| :---- | :---- | :---- | :---- |
| Data Integrity | Eventual consistency; lacks strict schema. | ACID compliant; strict foreign key constraints. | Ensures a collector cannot be assigned a deleted or invalid waste listing. |
| Geospatial Queries | Limited; requires complex client-side filtering. | Native PostGIS support (ST\_DWithin). | Allows instant matching of waste generators to the nearest available collector. |
| Authorization | Application-level rules. | Database-level Row Level Security (RLS). | Prevents unauthorized state changes (e.g., a generator marking their own waste as 'recycled'). |
| Real-time Subscriptions | Document listeners. | WAL logical replication (pgoutput). | Highly scalable broadcast of logistics updates directly to mobile clients. |

### **4.2 Real-Time Logistics Synchronization**

Real-time pickup scheduling and live tracking are achieved via Postgres's Write-Ahead Log (WAL). Through logical replication, changes to the database—such as a collector accepting a pickup request—are streamed to a distributed cluster, which broadcasts the payload over WebSockets directly to the generator's mobile application32. This completely eliminates the need for manual client-side polling, reducing server load and ensuring the mobile UI reacts instantly to state changes across the supply chain.

## **5\. Cryptographic Anti-Fraud and Image Deduplication**

A critical vulnerability in any incentivized waste exchange is systemic fraud. If waste generators receive rewards—such as tokens, tax credits, or gamified points—based on the volume of plastic they divert, malicious actors will inevitably attempt "replay attacks." A user could upload multiple photographs of the exact same batch of HDPE bottles from slightly different angles or under different lighting to fraudulently claim multiple rewards.  
Standard cryptographic hashes, such as SHA-256, are useless for this application. Resaving a JPEG, altering a single pixel, or applying slight image compression completely alters a cryptographic digest34. The platform requires an algorithmic mechanism where visually similar images yield mathematically similar signatures.

### **5.1 Perceptual Hashing (pHash) Implementation**

The platform must implement Perceptual Hashing (pHash) on the mobile client or edge server before validating and storing a listing. Unlike cryptographic hashes, pHash evaluates the structural, low-frequency visual data of an image, rendering it immune to minor alterations like cropping, resizing, or color shifts34.  
The Discrete Cosine Transform (DCT) pHash algorithm executes a highly deterministic pipeline:

> 1. **Normalization:** The uploaded image is converted to grayscale to remove color dependence, and aggressively downscaled to a 32x32 pixel grid using Lanczos resampling. This step destroys fragile high-frequency noise while preserving the coarse geometric structure of the waste34.  
> 2. **Frequency Transformation:** A two-dimensional Discrete Cosine Transform is applied to the 32x32 matrix, transitioning the data from the spatial domain to the frequency domain35.  
> 3. **Low-Frequency Extraction:** The algorithm extracts the top-left 8x8 matrix of the DCT output, which represents the lowest frequency components—essentially the macro-shapes of the bottles and containers34.  
> 4. **Median Thresholding:** The median value of these 64 coefficients is calculated. Each coefficient is then evaluated against this median: if it is greater, the bit is set to 1; otherwise, it is set to 034.

This process generates a highly compact 64-bit fingerprint that represents the core visual signature of the uploaded waste35.

### **5.2 Vector Similarity Search via pgvector**

When a new listing is submitted, its 64-bit pHash is stored in the PostgreSQL database alongside the waste metadata. To detect duplicates, the system must calculate the Hamming distance—the number of differing bits—between the new hash and all historical hashes in the geographical vicinity34. A Hamming distance of 0 to 5 bits indicates an almost certain duplicate, suggesting the same image was merely cropped or resized, while a distance above 15 indicates a distinct, legitimate batch of waste34.  
Performing a brute-force Hamming distance comparison across millions of records is computationally intractable and would severely bottleneck the platform. Therefore, the architecture utilizes the pgvector extension in PostgreSQL25. By casting the 64-bit hashes as binary vectors, the database can leverage a Hierarchical Navigable Small World (HNSW) index25.  
The HNSW algorithm builds a multi-layered graph of proximity. During a query, it navigates the upper sparse layers of the graph to rapidly zero in on the general neighborhood of the vector, before dropping to denser layers to find the exact nearest neighbors41. By configuring the pgvector HNSW index with Hamming distance operators (bit\_hamming\_ops), the database can execute near-instantaneous anomaly detection, proactively blocking fraudulent duplicate submissions before they ever enter the logistics queue25.

## **6\. Algorithmic Routing and Logistics Optimization**

Connecting waste generators to collectors is not a simple one-to-one mapping; at scale, it transforms into a highly constrained combinatorial optimization challenge known mathematically as the Capacitated Vehicle Routing Problem with Time Windows (CVRPTW)43.  
Collectors operating logistics networks command fleets of vehicles with fixed volumetric and weight capacities (e.g., a specific truck can safely transport a maximum of 2,000 kg of rigid HDPE). Simultaneously, generators stipulate specific time windows for pickup (e.g., a commercial campus requires pickup strictly between 09:00 AM and 11:00 AM). The objective of the platform is to dynamically assign unfulfilled waste listings to specific trucks, sequencing the stops to minimize the total traversal distance, fuel consumption, and operational carbon emissions, while strictly adhering to all vehicle capacities and temporal constraints43.

### **6.1 Google OR-Tools and Routing Heuristics**

Developing a bespoke routing engine is unnecessary and prone to error. The backend logistics engine should integrate Google OR-Tools, a highly optimized C++ library designed specifically for complex operations research47.  
Because CVRPTW is an NP-hard mathematical problem, finding the absolute mathematical optimum is computationally impossible at a city-wide scale within a reasonable timeframe. Instead, OR-Tools utilizes advanced heuristic and metaheuristic algorithms:

> 1. **Initial Solution Generation:** The engine uses the Clarke-Wright Savings algorithm to generate a rapid, feasible initial set of routes. This algorithm evaluates the distance "saved" by connecting two separate nodes into a single continuous tour rather than servicing them individually by returning to the central depot after each stop44.  
> 2. **Metaheuristic Optimization:** Once an initial route is established, OR-Tools applies Adaptive Large Neighborhood Search (ALNS). ALNS systematically destroys segments of the generated route and attempts to rebuild them using different insertion heuristics, continually searching for a lower-cost overall topology that satisfies all capacity and time window constraints44.

### **6.2 Distance Matrix Calculation via OSRM**

The fundamental input required by the OR-Tools solver is a complete Distance Matrix—a massive table indicating the exact travel time and driving distance between every single generator, the depot, and the recycling facility47. Relying on commercial APIs (such as the Google Maps Distance Matrix API) for continuous, real-time matrix generation is cost-prohibitive for a scaling startup.  
To resolve this, the platform must host an internal instance of the Open Source Routing Machine (OSRM) loaded with regional OpenStreetMap (OSM) data50. OSRM achieves millisecond query latency for continental-scale graphs by utilizing Contraction Hierarchies (CH)50. During an initial pre-processing phase, the CH algorithm adds "shortcut" edges to the road network graph, effectively bypassing minor residential nodes. At runtime, the routing algorithms only search "upward" toward the most prominent highways, drastically reducing the search space and delivering the dense distance matrices required by OR-Tools in a fraction of the time52.

## **7\. Environmental Impact Modeling and CO2 Calculation**

For the Circular Plastics Exchange to be commercially viable, it must transcend basic logistics and interface directly with international carbon accounting standards and national regulatory frameworks. The impact dashboard envisioned in the platform's core expectations is not merely a user interface visual aid; it acts as a verifiable financial reporting tool for corporate entities.  
To accurately calculate the metric tons of carbon dioxide equivalent (MTCO2E) avoided by diverting plastic from landfills or incineration to recycling facilities, the platform utilizes the United States Environmental Protection Agency’s Waste Reduction Model (EPA WARM v16)53. WARM provides peer-reviewed life-cycle assessment (LCA) emission factors for various material streams, establishing a rigorous baseline for environmental reporting.  
When the application's computer vision model detects and successfully diverts specific plastic resins, the backend applies the exact WARM emission factors to the final recorded weight:

* **HDPE (High-Density Polyethylene):** Diverting one short ton of HDPE to recycling yields a net greenhouse gas emission factor of 1.86 MTCO2E avoided relative to baseline disposal methods56.  
* **PET (Polyethylene Terephthalate):** Diverting one short ton of PET yields 1.55 MTCO2E avoided56.  
* **PP (Polypropylene):** Diverting one short ton yields 1.15 MTCO2E avoided56.

| Material Type | Management Pathway | Net Emissions Avoided (MTCO2E / Short Ton) | Energy Savings (Million BTU / Short Ton) |
| :---- | :---- | :---- | :---- |
| HDPE (Rigid Plastics) | Recycling | 1.86 | Significant displacement of virgin material energy. |
| PET (Clear Bottles) | Recycling | 1.55 | Reduces energy-intensive polymerization processes. |
| PP (Containers/Caps) | Recycling | 1.15 | Avoids landfill methane and combustion emissions. |

By multiplying the aggregate tonnage of verified deliveries by these specific LCAs, the platform produces audit-ready environmental impact reports. These reports are critical for corporate sustainability disclosures, allowing businesses utilizing the platform to accurately report their Environmental, Social, and Governance (ESG) metrics57.

## **8\. Traceability, Chain of Custody, and Macroeconomic Monetization**

The most lucrative mechanism for monetizing this platform is integration with statutory Extended Producer Responsibility (EPR) markets. Around the globe, regulatory frameworks are shifting the financial burden of waste management back onto the producers. A prime example is the framework established by the Central Pollution Control Board (CPCB) in India.  
Under the Plastic Waste Management (Amendment) Rules, all Producers, Importers, and Brand Owners (PIBOs) that introduce plastic packaging into the market are legally mandated to collect and recycle a specific percentage of that volume annually57. Because FMCG (Fast-Moving Consumer Goods) brands cannot build their own recycling plants, they must purchase **EPR Certificates** from authorized recyclers to meet their compliance targets57. Non-compliance results in severe Environmental Compensation penalties (up to ₹20,000 per tonne for repeated shortfalls) and potential business disruption60.

### **8.1 Monetizing Through EPR Certificate Trading**

The Circular Plastics Exchange acts as a digital ledger that provides pristine, geolocated, and visually verified chain-of-custody data to certified recyclers. When a recycler processes the platform's waste, they are authorized to generate digital EPR certificates on the centralized CPCB portal63.  
These certificates are highly valuable commodities. Market data indicates that Category I (Rigid Plastics like HDPE and PET) EPR certificates trade between ₹4,000 and ₹7,500 per metric tonne, while Category III (Multi-Layered Plastics) can trade higher due to processing difficulty62. The platform monetizes by taking a transaction fee on the data provenance that validates these multi-million-rupee credit trades on platforms like the EPR Exchange and Trading Platform (EPRETP)63.

### **8.2 Implementing the GS1 Digital Link for the Digital Product Passport**

To physically bridge the gap between the digital database listing and the physical waste batch moving through the supply chain, the platform employs the GS1 Digital Link standard, fulfilling the bonus expectation of providing a QR label for chain of custody67. GS1 Digital Link upgrades standard barcodes into web-resolvable URIs, conforming to the strict structural requirements of impending international regulations, such as the European Union Digital Product Passport (DPP)67.  
When a collector picks up a consolidated batch of sorted PET, the mobile application generates a QR code containing a standardized URL: https\://id.plant-x.com/01/{GTIN}/10/{BATCH}/21/{SERIAL}67. Because the identifier is a standard URL, the recycler at the destination facility can scan the incoming bale with any standard smartphone camera without requiring specialized software67.  
Through HTTP content negotiation, the backend resolver identifies the scanner's user agent and role. If an auditor scans the code, the server returns the JSON-LD chain-of-custody payload and the pHash verification record, proving the waste is not fraudulent. If a general consumer scans the code, they are redirected to an HTML landing page detailing the environmental impact67. This standardized data carrier ensures that the plastic's journey from generator to pelletization is cryptographically linked, globally interoperable, and fully compliant with international traceability mandates69.

## **9\. Synthesis and Conclusion**

The architecture required to successfully deploy the Circular Plastics Exchange extends far beyond the scope of a standard mobile application and a basic classification model. By synthesizing YOLOv11 edge-inferencing with Quantization-Aware Training, the platform achieves real-time, low-latency resin identification directly on consumer hardware, overcoming the severe limitations of standard post-training quantization. Utilizing React Native JSI frame processors ensures zero-copy memory efficiency, preserving battery life and device thermal stability far better than standard cross-platform serialization bridges.  
Transitioning from NoSQL document stores to PostgreSQL with Row Level Security guarantees strict multi-tenant data isolation, while the integration of pgvector and Perceptual Hashing eradicates systemic reward fraud by instantly detecting duplicate images. Finally, the integration of OSRM routing heuristics and EPA WARM / CPCB EPR compliance frameworks transforms a simple matching application into a mathematically optimized, financially lucrative, and regulatory-compliant commodity exchange. This holistic, interconnected technology stack not only solves the immediate technical challenge of waste matching but fundamentally institutionalizes the digital infrastructure required to sustain the global circular economy.

#### **Works cited**

> 1. (PDF) Identification and plastic type and classification of PET, HDPE, [https\://www\.researchgate.net/publication/342395204\_Identification\_and\_plastic\_type\_and\_classification\_of\_PET\_HDPE\_and\_PP\_using\_RGB\_method](https://www.researchgate.net/publication/342395204_Identification_and_plastic_type_and_classification_of_PET_HDPE_and_PP_using_RGB_method)  
> 2. (PDF) Application of Computer Vision Techniques for Segregation of, [https\://www\.researchgate.net/publication/345971024\_Application\_of\_Computer\_Vision\_Techniques\_for\_Segregation\_of\_PlasticWaste\_based\_on\_Resin\_Identification\_Code](https://www.researchgate.net/publication/345971024_Application_of_Computer_Vision_Techniques_for_Segregation_of_PlasticWaste_based_on_Resin_Identification_Code)  
> 3. Plastic Waste DataBase of Images – WaDaBa, [https\://wadaba.pcz.pl/](https://wadaba.pcz.pl/)  
> 4. Deep transfer learning benchmark for plastic waste classification, [https\://www\.oaepublish.com/articles/ir.2021.15](https://www.oaepublish.com/articles/ir.2021.15)  
> 5. Plastic Waste Detection Using Deep Learning, [https\://tecnoscientifica.com/journal/idwm/article/download/580/292](https://tecnoscientifica.com/journal/idwm/article/download/580/292)  
> 6. Plastic Waste Classification Using Deep Learning \- arXiv, [https\://arxiv.org/pdf/2412.20232?](https://arxiv.org/pdf/2412.20232)  
> 7. Deep Learning-Based Classification Of Plastic Waste Using Resin, [https\://www\.researchgate.net/publication/399218097\_Deep\_Learning-Based\_Classification\_Of\_Plastic\_Waste\_Using\_Resin\_Identification\_Codes](https://www.researchgate.net/publication/399218097_Deep_Learning-Based_Classification_Of_Plastic_Waste_Using_Resin_Identification_Codes)  
> 8. Plastic Waste Classification Using Deep Learning \- arXiv, [https\://arxiv.org/pdf/2412.20232](https://arxiv.org/pdf/2412.20232)  
> 9. Introducing the Next Generation of On-Device Vision Models, [https\://research.google/blog/introducing-the-next-generation-of-on-device-vision-models-mobilenetv3-and-mobilenetedgetpu/](https://research.google/blog/introducing-the-next-generation-of-on-device-vision-models-mobilenetv3-and-mobilenetedgetpu/)  
> 10. YOLOv8 vs YOLO11 Comparison \- Ultralytics YOLO, [https\://docs.ultralytics.com/compare/yolov8-vs-yolo11](https://docs.ultralytics.com/compare/yolov8-vs-yolo11)  
> 11. Benchmarking Mobile Vision Transformers for Fine-Grained, [https\://www\.preprints.org/manuscript/202610.2011](https://www.preprints.org/manuscript/202610.2011)  
> 12. Brief Review — MobileViTv3: Mobile-Friendly Vision Transformer, [https\://sh-tsang.medium.com/brief-review-mobilevitv3-mobile-friendly-vision-transformer-with-simple-and-effective-fusion-of-4faee5740a63](https://sh-tsang.medium.com/brief-review-mobilevitv3-mobile-friendly-vision-transformer-with-simple-and-effective-fusion-of-4faee5740a63)  
> 13. Post-training Quantization or Quantization-aware Training? That is, [https\://www\.researchgate.net/publication/373323125\_Post-training\_Quantization\_or\_Quantization-aware\_Training\_That\_is\_the\_Question](https://www.researchgate.net/publication/373323125_Post-training_Quantization_or_Quantization-aware_Training_That_is_the_Question)  
> 14. Quantization-Aware Training (QAT) vs. Post-Training ... \- Medium, [https\://medium.com/better-ml/quantization-aware-training-qat-vs-post-training-quantization-ptq-cd3244f43d9a](https://medium.com/better-ml/quantization-aware-training-qat-vs-post-training-quantization-ptq-cd3244f43d9a)  
> 15. Post-Training Quantization vs Quantization-Aware Training: A, [https\://ai.plainenglish.io/post-training-quantization-vs-quantization-aware-training-a-hands-on-comparison-with-a-small-llama-bc53e1fbb6d2](https://ai.plainenglish.io/post-training-quantization-vs-quantization-aware-training-a-hands-on-comparison-with-a-small-llama-bc53e1fbb6d2)  
> 16. Adding Quantization-aware Training and Pruning to the TensorFlow, [https\://blog.tensorflow.org/2022/06/Adding-Quantization-aware-Training-and-Pruning-to-the-TensorFlow-Model-Garden.html](https://blog.tensorflow.org/2022/06/Adding-Quantization-aware-Training-and-Pruning-to-the-TensorFlow-Model-Garden.html)  
> 17. QAT vs Post-Training Quantization \- Patsnap Eureka, [https\://eureka.patsnap.com/resources/blog/rd-blog/qat-vs-post-training-quantization-patsnap-eureka/](https://eureka.patsnap.com/resources/blog/rd-blog/qat-vs-post-training-quantization-patsnap-eureka/)  
> 18. Improving INT8 Accuracy Using Quantization Aware Training and, [https\://developer.nvidia.com/blog/improving-int8-accuracy-using-quantization-aware-training-and-tao-toolkit/](https://developer.nvidia.com/blog/improving-int8-accuracy-using-quantization-aware-training-and-tao-toolkit/)  
> 19. Flutter FFI Tutorial: Integrating Native C and C++ Libraries, [https\://dev.to/vmodal\_ai/flutter-ffi-tutorial-integrating-native-c-and-c-libraries-2ol9](https://dev.to/vmodal_ai/flutter-ffi-tutorial-integrating-native-c-and-c-libraries-2ol9)  
> 20. Zero-Copy GPU Compute on Camera Frames in React Native, [https\://dev.to/kbrandwijk/zero-copy-gpu-compute-on-camera-frames-in-react-native-what-actually-worked-512j](https://dev.to/kbrandwijk/zero-copy-gpu-compute-on-camera-frames-in-react-native-what-actually-worked-512j)  
> 21. Creating a high-performance React Native Vision Camera C++, [https\://medium.com/@lukasz.kurant/creating-a-high-performance-react-native-vision-camera-c-frame-processor-using-jsi-b00fa8df3221](https://medium.com/@lukasz.kurant/creating-a-high-performance-react-native-vision-camera-c-frame-processor-using-jsi-b00fa8df3221)  
> 22. Native Frame Processor Plugins \- VisionCamera \- Margelo, [https\://visioncamera.margelo.com/docs/native-frame-processor-plugins](https://visioncamera.margelo.com/docs/native-frame-processor-plugins)  
> 23. GitHub \- margelo/react-native-vision-camera-v4-snapshot, [https\://github.com/margelo/react-native-vision-camera-v4-snapshot](https://github.com/margelo/react-native-vision-camera-v4-snapshot)  
> 24. Row Level Security \| Supabase Docs, [https\://supabase.com/docs/guides/database/postgres/row-level-security](https://supabase.com/docs/guides/database/postgres/row-level-security)  
> 25. pgvector/pgvector: Open-source vector similarity search for Postgres, [https\://github.com/pgvector/pgvector](https://github.com/pgvector/pgvector)  
> 26. Authorization via Row Level Security \| Supabase Features, [https\://supabase.com/features/row-level-security](https://supabase.com/features/row-level-security)  
> 27. supabase/examples/prompts/database-rls-policies.md at master, [https\://github.com/supabase/supabase/blob/master/examples/prompts/database-rls-policies.md](https://github.com/supabase/supabase/blob/master/examples/prompts/database-rls-policies.md)  
> 28. Supabase RLS: USING vs WITH CHECK, Policy Examples, [https\://www\.rajeshdhiman.in/blog/supabase-rls-simplified-using-vs-with-check](https://www.rajeshdhiman.in/blog/supabase-rls-simplified-using-vs-with-check)  
> 29. Implement Row-Level Security Policies in Supabase SQL, [https\://dev.to/thebenforce/lock-down-your-data-implement-row-level-security-policies-in-supabase-sql-4p82](https://dev.to/thebenforce/lock-down-your-data-implement-row-level-security-policies-in-supabase-sql-4p82)  
> 30. Does the performance of Postgis function ST\_DWithin degrade with, [https\://gis.stackexchange.com/questions/224257/does-the-performance-of-postgis-function-st-dwithin-degrade-with-larger-distance](https://gis.stackexchange.com/questions/224257/does-the-performance-of-postgis-function-st-dwithin-degrade-with-larger-distance)  
> 31. Row Level Security performance \| Supabase Docs, [https\://supabase.com/docs/guides/database/postgres/row-level-security-performance](https://supabase.com/docs/guides/database/postgres/row-level-security-performance)  
> 32. What Is Supabase Realtime, and Why Does It Get Slow? \- AxonBuild, [https\://axonbuild.com/blog/supabase-realtime-slow/](https://axonbuild.com/blog/supabase-realtime-slow/)  
> 33. Introducing Realtime Broadcast from Database \- YouTube, [https\://www\.youtube.com/watch?v=vRorVm\_UbhA](https://www.youtube.com/watch?v=vRorVm_UbhA)  
> 34. pHash vs SHA-256: Perceptual Hash Explained \- MojoAuth, [https\://mojoauth.com/security-guides/sha-256-vs-phash](https://mojoauth.com/security-guides/sha-256-vs-phash)  
> 35. Comparative Evaluation of Perceptual Hashing and Deep ... \- MDPI, [https\://www\.mdpi.com/2079-9292/15/7/1493](https://www.mdpi.com/2079-9292/15/7/1493)  
> 36. Perceptual Image Hashing for Near-Duplicate Detection \- Mixpeek, [https\://mixpeek.com/guides/perceptual-image-hashing-near-duplicate-detection](https://mixpeek.com/guides/perceptual-image-hashing-near-duplicate-detection)  
> 37. Image embedding using Perceptual Hashing(pHash) technique, [https\://medium.com/@rajatraturi95/image-embedding-using-perceptual-hashing-phash-technique-a4d46e977f28](https://medium.com/@rajatraturi95/image-embedding-using-perceptual-hashing-phash-technique-a4d46e977f28)  
> 38. Perceptual Hashing (pHash/dHash) \- System Designer, [https\://www\.systemdesigner.net/technology/perceptual-hashing](https://www.systemdesigner.net/technology/perceptual-hashing)  
> 39. Perceptual Hashing in Node.js with Sharp pHash for Developers, [https\://www\.context.dev/blog/perceptual-hashing-in-node-js-with-sharp-phash-for-developers](https://www.context.dev/blog/perceptual-hashing-in-node-js-with-sharp-phash-for-developers)  
> 40. pgvector performance: Benchmark results and 5 ways to boost, [https\://www\.instaclustr.com/education/vector-database/pgvector-performance-benchmark-results-and-5-ways-to-boost-performance/](https://www.instaclustr.com/education/vector-database/pgvector-performance-benchmark-results-and-5-ways-to-boost-performance/)  
> 41. HNSW Indexes with Postgres and pgvector \| Crunchy Data Blog, [https\://www\.crunchydata.com/blog/hnsw-indexes-with-postgres-and-pgvector](https://www.crunchydata.com/blog/hnsw-indexes-with-postgres-and-pgvector)  
> 42. All You Need To Know About PGVector \| Part 6 — Quantization, [https\://medium.com/@aysebilgegunduz/all-you-need-to-know-about-pgvector-part-6-quantization-0920ffec6203](https://medium.com/@aysebilgegunduz/all-you-need-to-know-about-pgvector-part-6-quantization-0920ffec6203)  
> 43. The pickup and delivery problem with time windows and scheduling, [https\://arxiv.org/html/2511.07681v1](https://arxiv.org/html/2511.07681v1)  
> 44. GitHub \- arora-amit37/cvrptw\_clarke\_wright: The repository uses the, [https\://github.com/arora-amit37/cvrptw\_clarke\_wright](https://github.com/arora-amit37/cvrptw_clarke_wright)  
> 45. Solving a capacitated vehicle routing problem with Google OR-Tools, [https\://medium.com/@brockarnold/solving-a-capacitated-vehicle-routing-problem-with-google-or-tools-and-mapbox-a2eeb6b47bca](https://medium.com/@brockarnold/solving-a-capacitated-vehicle-routing-problem-with-google-or-tools-and-mapbox-a2eeb6b47bca)  
> 46. Waste Collection VRPTW Optimization \| PDF \| Routing \- Scribd, [https\://www\.scribd.com/document/891157340/Waste-Collection-Vehicle-Routing-Problem-With-Time-Windows](https://www.scribd.com/document/891157340/Waste-Collection-Vehicle-Routing-Problem-With-Time-Windows)  
> 47. Google OR-Tools Optimizing Routing and Scheduling Problems., [https\://www\.scirp.org/reference/referencespapers?referenceid=3878907](https://www.scirp.org/reference/referencespapers?referenceid=3878907)  
> 48. Vehicle routing problem in a medical facility waste collection company, [https\://ijtech.eng.ui.ac.id/article/view/5937](https://ijtech.eng.ui.ac.id/article/view/5937)  
> 49. Routing Options \| OR-Tools \- Google for Developers, [https\://developers.google.com/optimization/routing/routing\_options](https://developers.google.com/optimization/routing/routing_options)  
> 50. Project OSRM, [https\://project-osrm.org/](https://project-osrm.org/)  
> 51. GraphHopper Distance Matrix: Self-Host & Benchmarks, [https\://tanhdev.com/posts/graphhopper-distance-matrix-production-guide/](https://tanhdev.com/posts/graphhopper-distance-matrix-production-guide/)  
> 52. Anyone who's interested in this might want to check out the OSRM, [https\://news.ycombinator.com/item?id=12640162](https://news.ycombinator.com/item?id=12640162)  
> 53. PLASTICS \- EPA Archive, [https\://archive.epa.gov/epawaste/conserve/tools/warm/pdfs/Plastics.pdf](https://archive.epa.gov/epawaste/conserve/tools/warm/pdfs/Plastics.pdf)  
> 54. Versions of the Waste Reduction Model \| US EPA, [https\://www\.epa.gov/waste-reduction-model/versions-waste-reduction-model](https://www.epa.gov/waste-reduction-model/versions-waste-reduction-model)  
> 55. WARM Excel User's Guide – Version 16 \- EPA, [https\://www\.epa.gov/system/files/documents/2023-12/warm-users-guide-excel\_v16\_dec.pdf](https://www.epa.gov/system/files/documents/2023-12/warm-users-guide-excel_v16_dec.pdf)  
> 56. Documentation for Greenhouse Gas Emission and Energy Factors, [https\://www\.epa.gov/system/files/documents/2023-12/warm\_containers\_packaging\_and\_non-durable\_goods\_materials\_v16\_dec.pdf](https://www.epa.gov/system/files/documents/2023-12/warm_containers_packaging_and_non-durable_goods_materials_v16_dec.pdf)  
> 57. EPR Compliance in India \| CPCB-Aligned Expert Support, [https\://enterclimate.com/epr-compliance-in-india](https://enterclimate.com/epr-compliance-in-india)  
> 58. EPR Registration for Plastic Waste 2026: Complete Guide \- IncorpX, [https\://www\.incorpx.io/blog/epr-registration-plastic-waste-2026](https://www.incorpx.io/blog/epr-registration-plastic-waste-2026)  
> 59. Centralized EPR Portal for Plastic Packaging, [https\://eprplastic.cpcb.gov.in/](https://eprplastic.cpcb.gov.in/)  
> 60. How Plastic Waste EPR Credits Work in India (2026 Guide), [https\://www\.imarcengineering.com/blog/how-plastic-waste-epr-credits-work-in-india](https://www.imarcengineering.com/blog/how-plastic-waste-epr-credits-work-in-india)  
> 61. EPR Certificate India: What It Is & How to Register \- Gravita India, [https\://www\.gravitaindia.com/blogs/epr-certificate-india-what-it-is-who-needs-it-how-to-register](https://www.gravitaindia.com/blogs/epr-certificate-india-what-it-is-who-needs-it-how-to-register)  
> 62. EPR Plastic Waste Documents & Registration Guide 2026, [https\://blogs.seyecs.com/epr-plastic-waste-documents/](https://blogs.seyecs.com/epr-plastic-waste-documents/)  
> 63. EPR Certificate: Meaning, Process, Documents & How to Apply (2026), [https\://eprsolutions.in/blog/epr-certificates-explained-issuance-and-trading](https://eprsolutions.in/blog/epr-certificates-explained-issuance-and-trading)  
> 64. EPR Cost for Indian SMEs: Real Numbers for 2026, [https\://www\.nationalrecycling.in/blog/epr-cost-sme-india-real-numbers-breakdown/](https://www.nationalrecycling.in/blog/epr-cost-sme-india-real-numbers-breakdown/)  
> 65. के \- Centralized EPR Portal for Plastic Packaging, [https\://eprplastic.cpcb.gov.in/plastic/downloads/All\_SCN\_11\_Unit.pdf](https://eprplastic.cpcb.gov.in/plastic/downloads/All_SCN_11_Unit.pdf)  
> 66. Plastic EPR Credit Prices \- Live Rates India, [https\://epr.enviraj.com/plastic-epr-credit-prices-live-rates-india.html](https://epr.enviraj.com/plastic-epr-credit-prices-live-rates-india.html)  
> 67. GS1 Digital Link for the digital product passport, [https\://eudigitalproductpassport.org/standards/gs1-digital-link](https://eudigitalproductpassport.org/standards/gs1-digital-link)  
> 68. GS1 Digital Link Explained: Complete Guide \- MyProductPassport, [https\://myproductpassport.eu/blog/gs1-digital-link-explained-complete-guide](https://myproductpassport.eu/blog/gs1-digital-link-explained-complete-guide)  
> 69. GS1 Digital Link: How It Works for Digital Product Passports, [https\://www\.bdemerson.com/article/gs1-digital-link](https://www.bdemerson.com/article/gs1-digital-link)  
> 70. GS1 Standards enabling the EU digital product passport, [https\://gs1.eu/wp-content/uploads/2025/04/GS1-Standards-Enabling-DPP-V2.2.pdf](https://gs1.eu/wp-content/uploads/2025/04/GS1-Standards-Enabling-DPP-V2.2.pdf)  
> 71. GS1 Digital Link & DPP — How the Standard Works, [https\://dpp-tool.com/en/guide/gs1-digital-link/](https://dpp-tool.com/en/guide/gs1-digital-link/)  
> 72. GS1 Digital Link Explained: One QR Code, All Data \- Tappr, [https\://www\.usetappr.com/regulation/gs1-digital-link/](https://www.usetappr.com/regulation/gs1-digital-link/)  
> 73. GS1 for DPP: The Global Standard for Digital Product Passports, [https\://tracextech.com/gs1-for-dpp/](https://tracextech.com/gs1-for-dpp/)